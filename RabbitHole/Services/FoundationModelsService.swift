import Foundation
import FoundationModels

actor FoundationModelsService {

    // MARK: - Node Story Generation

    func generateNodeStory(title: String, rawSummary: String) async throws -> String {
        let session = LanguageModelSession()
        let prompt = """
        Write a 4-5 sentence narrative about "\(title)" for an intellectual curiosity app.

        Raw Wikipedia summary to draw from:
        \(rawSummary.prefix(800))

        Rules:
        1. Open with a surprising origin, paradox, or human moment — not a definition
        2. Second sentence: what it actually is, in plain language
        3. Third sentence: why it mattered — consequence or ripple effect
        4. Final sentence: the thread forward — what makes it a rabbit hole, what else it connects to
        5. Write as narrative, not summary. Make the reader feel something.
        6. Do NOT start with "\(title)" or "This is" or any encyclopedia phrasing
        7. Under 80 words total

        Output only the story, no labels or quotes.
        """
        let response = try await session.respond(to: prompt)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Connection Discovery

    struct SemanticConnection {
        let targetTitle: String
        let sentence: String
        let surpriseScore: Double   // 0–1, higher = more surprising
        let isCrossDomain: Bool
    }

    func discoverSemanticConnections(
        sourceTitle: String,
        sourceStory: String,
        candidateTitles: [String]
    ) async throws -> [SemanticConnection] {
        let session = LanguageModelSession()
        let candidateList = candidateTitles.prefix(30).enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")

        let prompt = """
        Source topic: "\(sourceTitle)"
        Source context: \(sourceStory.prefix(300))

        Candidate topics:
        \(candidateList)

        For each candidate, rate the connection on two dimensions:
        - surprise (0-10): how unexpected is this connection? Prefer cross-domain jumps.
        - relevance (0-10): is the connection defensible, not just random?

        Select the 5 best candidates that have HIGH surprise (7+) AND reasonable relevance (5+).
        For each, write exactly ONE sentence that explains WHY they connect — not what they are.
        The sentence should make someone think "I didn't expect that."

        Output as JSON array:
        [{"title": "...", "sentence": "...", "surprise": 8, "relevance": 7, "crossDomain": true}]
        Output only valid JSON, nothing else.
        """

        let response = try await session.respond(to: prompt)
        let jsonString = extractJSON(from: response.content)
        let data = Data(jsonString.utf8)
        let decoded = try JSONDecoder().decode([ConnectionCandidate].self, from: data)

        return decoded.map { candidate in
            SemanticConnection(
                targetTitle: candidate.title,
                sentence: candidate.sentence,
                surpriseScore: Double(candidate.surprise) / 10.0,
                isCrossDomain: candidate.crossDomain
            )
        }
    }

    // MARK: - Connection Sentence Generation

    func generateConnectionSentence(
        fromTitle: String,
        toTitle: String,
        fromStory: String,
        toStory: String
    ) async throws -> String {
        let session = LanguageModelSession()
        let prompt = """
        Write ONE sentence explaining how "\(fromTitle)" connects to "\(toTitle)".

        Context for \(fromTitle): \(fromStory.prefix(200))
        Context for \(toTitle): \(toStory.prefix(200))

        Rules:
        - Explain WHY they connect, not what either topic is
        - Surprising angle preferred over obvious one
        - Under 20 words
        - No quotes, no labels
        - This sentence must stop a thumb mid-scroll

        Output only the sentence.
        """
        let response = try await session.respond(to: prompt)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Daily Surface Generation

    func generateDailySurfaceHeadline(
        cardType: String,
        context: String
    ) async throws -> String {
        let session = LanguageModelSession()
        let prompt = """
        Generate a short, personal headline for a daily surface card.
        Card type: \(cardType)
        Context: \(context)

        Rules:
        - Under 12 words
        - Personal, specific, not generic
        - Should feel like it could only exist for this user
        - No quotes, no punctuation at end

        Output only the headline.
        """
        let response = try await session.respond(to: prompt)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers

    private func extractJSON(from text: String) -> String {
        if let start = text.firstIndex(of: "["),
           let end = text.lastIndex(of: "]") {
            return String(text[start...end])
        }
        return "[]"
    }
}

private struct ConnectionCandidate: Decodable {
    let title: String
    let sentence: String
    let surprise: Int
    let relevance: Int
    let crossDomain: Bool
}
