import Foundation
import SwiftData

@MainActor
final class DailySurfaceService {
    private let llm = FoundationModelsService()
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func generateDailyCards() async throws -> [DailySurfaceCard] {
        var cards: [DailySurfaceCard] = []

        let dives = fetchAllDives()
        let nodes = fetchAllNodes()

        // 1. Forgotten threads — nodes with no outgoing explored connections
        if let forgottenCard = await makeForgottenThreadCard(nodes: nodes) {
            cards.append(forgottenCard)
        }

        // 2. Unexpected bridge — two dives sharing a node
        if let bridgeCard = await makeUnexpectedBridgeCard(dives: dives) {
            cards.append(bridgeCard)
        }

        // 3. Road not taken — unattempted 🔴 connections
        if let roadCard = await makeRoadNotTakenCard(nodes: nodes) {
            cards.append(roadCard)
        }

        // 4. Domain portrait — weekly theme
        if let portraitCard = await makeDomainPortraitCard(nodes: nodes) {
            cards.append(portraitCard)
        }

        // 5. Dormant dive
        if let dormantCard = await makeDormantDiveCard(dives: dives) {
            cards.append(dormantCard)
        }

        for card in cards { modelContext.insert(card) }
        try modelContext.save()
        return cards
    }

    // MARK: - Card Makers

    private func makeForgottenThreadCard(nodes: [Node]) async -> DailySurfaceCard? {
        // Find a node that has been visited but has unexplored connections
        guard let node = nodes
            .filter({ $0.lastVisitedAt != nil && !$0.outgoingConnections.isEmpty })
            .filter({ !$0.outgoingConnections.allSatisfy(\.isExplored) })
            .randomElement() else { return nil }

        let weeksAgo = node.lastVisitedAt.map { weeksAgo(from: $0) } ?? 1
        let headline = "\(weeksAgo == 1 ? "Last week" : "\(weeksAgo) weeks ago") you stopped at \(node.title)"
        let card = DailySurfaceCard(
            type: .forgottenThread,
            headline: headline,
            body: "You explored this but never followed where it leads."
        )
        card.relatedNodeID = node.id
        return card
    }

    private func makeUnexpectedBridgeCard(dives: [Dive]) async -> DailySurfaceCard? {
        // Find two dives that share a common node
        var nodeIDToDives: [String: [Dive]] = [:]
        for dive in dives {
            for step in dive.trail {
                guard let nodeID = step.node?.id else { continue }
                nodeIDToDives[nodeID, default: []].append(dive)
            }
        }
        guard let (sharedNodeID, sharedDives) = nodeIDToDives
            .filter({ $0.value.count >= 2 })
            .first,
              let diveA = sharedDives.first,
              let diveB = sharedDives.dropFirst().first
        else { return nil }

        let card = DailySurfaceCard(
            type: .unexpectedBridge,
            headline: "Your \"\(diveA.name)\" and \"\(diveB.name)\" dives meet here",
            body: "Two separate threads share the same node."
        )
        card.bridgeNodeID = sharedNodeID
        card.diveAID = diveA.id
        card.diveBID = diveB.id
        return card
    }

    private func makeRoadNotTakenCard(nodes: [Node]) async -> DailySurfaceCard? {
        // Find an unexplored 🔴 red connection
        let unexploredRed = nodes
            .flatMap(\.outgoingConnections)
            .filter { !$0.isExplored && $0.tier == .rabbitHole }
        guard let connection = unexploredRed.randomElement(),
              let target = connection.targetNode else { return nil }

        let card = DailySurfaceCard(
            type: .roadNotTaken,
            headline: "You didn't go here. Want to?",
            body: connection.connectionSentence
        )
        card.relatedNodeID = target.id
        card.skippedConnectionID = connection.id
        return card
    }

    private func makeDomainPortraitCard(nodes: [Node]) async -> DailySurfaceCard? {
        // Find theme from nodes visited in the last 7 days
        let recentNodes = nodes.filter {
            guard let visited = $0.lastVisitedAt else { return false }
            return Date().timeIntervalSince(visited) < 7 * 24 * 3600
        }
        guard recentNodes.count >= 3 else { return nil }

        let titles = recentNodes.prefix(8).map(\.title).joined(separator: ", ")
        let headline = (try? await llm.generateDailySurfaceHeadline(
            cardType: "domain_portrait",
            context: "Recent topics: \(titles)"
        )) ?? "This week you kept returning to the same thread"

        return DailySurfaceCard(
            type: .domainPortrait,
            headline: headline,
            body: "A pattern is forming in your exploration."
        )
    }

    private func makeDormantDiveCard(dives: [Dive]) async -> DailySurfaceCard? {
        guard let dormant = dives.filter(\.isDormant).randomElement() else { return nil }
        let card = DailySurfaceCard(
            type: .dormantDive,
            headline: "You left \"\(dormant.name)\" open",
            body: "This dive has been waiting for you."
        )
        card.relatedDiveID = dormant.id
        return card
    }

    // MARK: - Helpers

    private func fetchAllDives() -> [Dive] {
        let descriptor = FetchDescriptor<Dive>(predicate: #Predicate { !$0.isArchived })
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchAllNodes() -> [Node] {
        (try? modelContext.fetch(FetchDescriptor<Node>())) ?? []
    }

    private func weeksAgo(from date: Date) -> Int {
        max(1, Int(Date().timeIntervalSince(date) / (7 * 24 * 3600)))
    }
}
