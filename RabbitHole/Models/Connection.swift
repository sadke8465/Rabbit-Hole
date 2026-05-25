import Foundation
import SwiftData

enum ConnectionTier: Int, Codable {
    case closelyRelated = 1     // 🔵 Blue — same domain, obvious next step
    case unexpectedAngle = 2    // 🟡 Yellow — cross-domain, reframes the topic
    case rabbitHole = 3         // 🔴 Red — hidden influence, underlinked gem
}

@Model
final class Connection {
    var id: UUID
    var connectionSentence: String   // The one sentence that stops the thumb
    var tier: ConnectionTier
    var score: Double                // 0–1 composite score
    var isStructural: Bool           // Found via Wikipedia links (vs semantic only)
    var createdAt: Date
    var isExplored: Bool             // User has tapped through this connection

    var sourceNode: Node?
    var targetNode: Node?

    init(
        sourceNode: Node,
        targetNode: Node,
        connectionSentence: String,
        tier: ConnectionTier,
        score: Double,
        isStructural: Bool = false
    ) {
        self.id = UUID()
        self.sourceNode = sourceNode
        self.targetNode = targetNode
        self.connectionSentence = connectionSentence
        self.tier = tier
        self.score = score
        self.isStructural = isStructural
        self.isExplored = false
        self.createdAt = Date()
    }
}
