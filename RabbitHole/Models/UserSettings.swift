import Foundation
import SwiftData

@Model
final class UserSettings {
    var id: UUID
    var isPro: Bool
    var dailySurfaceLastGeneratedAt: Date?
    var totalNodesExplored: Int
    var totalDives: Int

    static let maxFreeDives = 3

    init() {
        self.id = UUID()
        self.isPro = false
        self.totalNodesExplored = 0
        self.totalDives = 0
    }
}
