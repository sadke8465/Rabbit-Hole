import Foundation
import SwiftData

/// Orchestrates the full pipeline: fetch Wikipedia → generate story → score connections → cache
@MainActor
final class NodeGenerationPipeline: ObservableObject {
    private let wikipedia = WikipediaService()
    private let wikidata = WikidataService()
    private let llm = FoundationModelsService()
    private let scorer = ConnectionScoringService()
    private let modelContext: ModelContext

    @Published var isGenerating = false
    @Published var generationProgress: GenerationProgress = .idle

    enum GenerationProgress: Equatable {
        case idle
        case fetchingArticle
        case generatingStory
        case discoveringConnections
        case scoringConnections
        case complete
        case failed(String)
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Node Story Pipeline

    func ensureNodeReady(title: String) async throws -> Node {
        // Return cached node if story already generated
        if let existing = fetchNode(id: title), existing.isStoryGenerated {
            return existing
        }

        isGenerating = true
        defer { isGenerating = false }

        generationProgress = .fetchingArticle
        let article = try await wikipedia.fetchArticle(title: title)

        generationProgress = .generatingStory
        let story: String
        do {
            story = try await llm.generateNodeStory(title: article.title, rawSummary: article.summary)
        } catch {
            // Foundation Models unavailable or failed — use Wikipedia summary as-is
            story = article.summary
        }

        let node: Node
        if let existing = fetchNode(id: article.normalizedTitle) {
            existing.story = story
            existing.wikipediaSummary = article.summary
            node = existing
        } else {
            node = Node(id: article.normalizedTitle, title: article.title, story: story, wikipediaSummary: article.summary)
            modelContext.insert(node)
        }
        try modelContext.save()

        generationProgress = .complete
        return node
    }

    // MARK: - Connection Discovery Pipeline

    func discoverConnections(for node: Node) async throws -> [ScoredConnection] {
        generationProgress = .discoveringConnections

        let article = try await wikipedia.fetchArticle(title: node.title)

        // Structural candidates from Wikipedia links
        let structuralTitles = Set(article.links.prefix(50))

        // Merge candidates
        var allCandidates: [(title: String, sentence: String, isStructural: Bool, isCrossDomain: Bool, surpriseScore: Double)] = []

        // Semantic candidates from Foundation Models — fall back to structural links if unavailable
        do {
            let semanticConnections = try await llm.discoverSemanticConnections(
                sourceTitle: node.title,
                sourceStory: node.story,
                candidateTitles: Array(structuralTitles)
            )
            for sem in semanticConnections {
                allCandidates.append((
                    title: sem.targetTitle,
                    sentence: sem.sentence,
                    isStructural: structuralTitles.contains(sem.targetTitle),
                    isCrossDomain: sem.isCrossDomain,
                    surpriseScore: sem.surpriseScore
                ))
            }
        } catch {
            // Foundation Models unavailable or failed — use Wikipedia links as structural candidates
            for title in structuralTitles.prefix(15) {
                allCandidates.append((
                    title: title,
                    sentence: "A topic linked from \(node.title) on Wikipedia.",
                    isStructural: true,
                    isCrossDomain: false,
                    surpriseScore: 0.3
                ))
            }
        }

        // Wikidata typed relationships if available (best-effort)
        var wikidataRelationships: [WikidataRelationship] = []
        if let wikidataID = article.wikidataID {
            wikidataRelationships = (try? await wikidata.fetchRelationships(wikidataID: wikidataID)) ?? []
        }

        // Add any Wikidata relationships not already covered
        let coveredTitles = Set(allCandidates.map(\.title))
        for rel in wikidataRelationships where !coveredTitles.contains(rel.targetTitle) {
            allCandidates.append((
                title: rel.targetTitle,
                sentence: "\(rel.relationshipType.replacingOccurrences(of: "_", with: " ").capitalized) of \(node.title).",
                isStructural: false,
                isCrossDomain: true,
                surpriseScore: 0.6
            ))
        }

        generationProgress = .scoringConnections
        let scored = await scorer.score(
            source: node.title,
            candidates: allCandidates,
            megaArticles: ConnectionScoringService.knownMegaArticles
        )

        return Array(scored.prefix(15))
    }

    // MARK: - Helpers

    private func fetchNode(id: String) -> Node? {
        let descriptor = FetchDescriptor<Node>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }
}
