import Foundation
import SwiftData

@Model
final class Dive {
    @Attribute(.unique) var id: UUID
    var name: String
    var seedNodeID: String           // The node that started this dive
    var createdAt: Date
    var lastActiveAt: Date
    var isArchived: Bool

    @Relationship(deleteRule: .cascade, inverse: \TrailStep.dive)
    var trail: [TrailStep] = []

    var isDormant: Bool {
        Date().timeIntervalSince(lastActiveAt) > 30 * 24 * 3600
    }

    var nodeCount: Int { trail.count }

    init(name: String, seedNodeID: String) {
        self.id = UUID()
        self.name = name
        self.seedNodeID = seedNodeID
        self.createdAt = Date()
        self.lastActiveAt = Date()
        self.isArchived = false
    }
}

@Model
final class TrailStep {
    var id: UUID
    var position: Int               // Order in the trail
    var visitedAt: Date
    var branchDepth: Int            // 0 = main trail, >0 = branch

    var dive: Dive?
    var node: Node?

    // Which connection was used to arrive here (nil for seed node)
    var arrivalConnectionID: UUID?

    init(node: Node, dive: Dive, position: Int, branchDepth: Int = 0, arrivalConnectionID: UUID? = nil) {
        self.id = UUID()
        self.node = node
        self.dive = dive
        self.position = position
        self.branchDepth = branchDepth
        self.arrivalConnectionID = arrivalConnectionID
        self.visitedAt = Date()
    }
}
