import Foundation
import SwiftData

enum DailySurfaceCardType: String, Codable {
    case forgottenThread     // Node visited but never expanded
    case unexpectedBridge    // Two dives share a node
    case roadNotTaken        // A 🔴 red card that was skipped
    case domainPortrait      // Week-level theme surfaced
    case dormantDive         // Untouched dive 30+ days
}

@Model
final class DailySurfaceCard {
    var id: UUID
    var type: DailySurfaceCardType
    var headline: String
    var body: String
    var generatedAt: Date
    var isDismissed: Bool
    var isTapped: Bool

    // Payloads — only one set will be non-nil depending on type
    var relatedNodeID: String?
    var relatedDiveID: UUID?
    var bridgeNodeID: String?       // For unexpectedBridge: the shared node
    var diveAID: UUID?
    var diveBID: UUID?
    var skippedConnectionID: UUID?

    init(type: DailySurfaceCardType, headline: String, body: String) {
        self.id = UUID()
        self.type = type
        self.headline = headline
        self.body = body
        self.generatedAt = Date()
        self.isDismissed = false
        self.isTapped = false
    }
}
