import Foundation
import NaturalLanguage

struct ScoredConnection {
    let title: String
    let sentence: String
    let tier: ConnectionTier
    let score: Double
    let isStructural: Bool
}

actor ConnectionScoringService {
    private let embedding = NLEmbedding.wordEmbedding(for: .english)

    // Target semantic distance for yellow/red tier: middle band (not too close, not too random)
    private let idealDistanceLow = 0.35
    private let idealDistanceHigh = 0.75

    func score(
        source: String,
        candidates: [(title: String, sentence: String, isStructural: Bool, isCrossDomain: Bool, surpriseScore: Double)],
        megaArticles: Set<String> = []
    ) -> [ScoredConnection] {
        candidates.map { candidate in
            let raw = computeRawScore(
                source: source,
                candidate: candidate,
                megaArticles: megaArticles.contains(candidate.title)
            )
            let tier = determineTier(score: raw, isCrossDomain: candidate.isCrossDomain, surpriseScore: candidate.surpriseScore)
            return ScoredConnection(
                title: candidate.title,
                sentence: candidate.sentence,
                tier: tier,
                score: raw,
                isStructural: candidate.isStructural
            )
        }
        .sorted { $0.score > $1.score }
    }

    private func computeRawScore(
        source: String,
        candidate: (title: String, sentence: String, isStructural: Bool, isCrossDomain: Bool, surpriseScore: Double),
        megaArticles: Bool
    ) -> Double {
        var score = 0.0

        // Semantic surprise from Foundation Models
        score += candidate.surpriseScore * 0.30

        // Cross-domain bonus
        if candidate.isCrossDomain { score += 0.25 }

        // Structural link (appears in article) — positive but not dominant
        if candidate.isStructural { score += 0.15 }

        // Semantic distance via NL embedding — prefer middle band
        if let distance = semanticDistance(source, candidate.title) {
            let distanceScore = gaussianBandScore(distance, low: idealDistanceLow, high: idealDistanceHigh)
            score += distanceScore * 0.20
        }

        // Mega-article penalty
        if megaArticles { score -= 0.25 }

        return max(0, min(1, score))
    }

    private func determineTier(score: Double, isCrossDomain: Bool, surpriseScore: Double) -> ConnectionTier {
        if surpriseScore >= 0.75 && isCrossDomain { return .rabbitHole }
        if isCrossDomain || surpriseScore >= 0.55 { return .unexpectedAngle }
        return .closelyRelated
    }

    private func semanticDistance(_ a: String, _ b: String) -> Double? {
        guard let emb = embedding else { return nil }
        let wordsA = a.lowercased().components(separatedBy: " ").first ?? a
        let wordsB = b.lowercased().components(separatedBy: " ").first ?? b
        return Double(emb.distance(between: wordsA, and: wordsB))
    }

    private func gaussianBandScore(_ value: Double, low: Double, high: Double) -> Double {
        let center = (low + high) / 2
        let width = (high - low) / 2
        let diff = value - center
        return exp(-(diff * diff) / (2 * width * width))
    }


}

// Known mega-articles that dilute connection quality
extension ConnectionScoringService {
    static let knownMegaArticles: Set<String> = [
        "United States", "England", "France", "Germany", "History",
        "Science", "Mathematics", "Physics", "Chemistry", "Biology",
        "Europe", "World War II", "Christianity", "Islam",
        "London", "New York City", "China", "India"
    ]
}
