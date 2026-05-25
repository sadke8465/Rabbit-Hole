import Foundation
import SwiftData

@Model
final class Node {
    @Attribute(.unique) var id: String  // Wikipedia page title (normalized)
    var title: String
    var story: String                   // Generated 4-5 sentence narrative
    var wikipediaSummary: String        // Raw intro text from Wikipedia
    var createdAt: Date
    var lastVisitedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \Connection.sourceNode)
    var outgoingConnections: [Connection] = []

    @Relationship(deleteRule: .cascade, inverse: \Connection.targetNode)
    var incomingConnections: [Connection] = []

    @Relationship(inverse: \TrailStep.node)
    var trailSteps: [TrailStep] = []

    var isStoryGenerated: Bool { !story.isEmpty }

    init(id: String, title: String, story: String = "", wikipediaSummary: String = "") {
        self.id = id
        self.title = title
        self.story = story
        self.wikipediaSummary = wikipediaSummary
        self.createdAt = Date()
    }
}
