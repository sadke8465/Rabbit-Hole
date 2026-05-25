import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class DiveViewModel {
    var currentNode: Node?
    var connectionCandidates: [ScoredConnection] = []
    var isLoadingNode = false
    var isLoadingConnections = false
    var error: String?

    // The current dive being explored
    var dive: Dive?

    // Cached pool — 15-20 pre-fetched connections, reshuffle is instant
    private var connectionPool: [ScoredConnection] = []
    private let poolSize = 15
    private let displaySize = 6

    let pipeline: NodeGenerationPipeline

    init(modelContext: ModelContext) {
        self.pipeline = NodeGenerationPipeline(modelContext: modelContext)
    }

    // MARK: - Navigation

    func startDive(title: String, diveName: String, modelContext: ModelContext) async {
        isLoadingNode = true
        defer { isLoadingNode = false }

        do {
            let node = try await pipeline.ensureNodeReady(title: title)
            let dive = Dive(name: diveName, seedNodeID: node.id)
            modelContext.insert(dive)
            let step = TrailStep(node: node, dive: dive, position: 0)
            modelContext.insert(step)
            try modelContext.save()

            self.dive = dive
            currentNode = node
            node.lastVisitedAt = Date()

            await prefetchConnectionPool(for: node)
            refreshDisplayedConnections()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func navigate(to connection: ScoredConnection, modelContext: ModelContext) async {
        guard let dive, let current = currentNode else { return }

        isLoadingNode = true
        defer { isLoadingNode = false }

        do {
            let targetNode = try await pipeline.ensureNodeReady(title: connection.title)

            // Mark connection as explored
            if let conn = current.outgoingConnections.first(where: { $0.targetNode?.id == targetNode.id }) {
                conn.isExplored = true
            } else {
                // Persist the connection if not already in SwiftData
                let conn = Connection(
                    sourceNode: current,
                    targetNode: targetNode,
                    connectionSentence: connection.sentence,
                    tier: connection.tier,
                    score: connection.score,
                    isStructural: connection.isStructural
                )
                conn.isExplored = true
                modelContext.insert(conn)
            }

            let nextPosition = (dive.trail.map(\.position).max() ?? -1) + 1
            let step = TrailStep(node: targetNode, dive: dive, position: nextPosition)
            modelContext.insert(step)
            dive.lastActiveAt = Date()
            targetNode.lastVisitedAt = Date()
            try modelContext.save()

            currentNode = targetNode
            HapticFeedbackManager.shared.success()
            await prefetchConnectionPool(for: targetNode)
            refreshDisplayedConnections()
        } catch {
            self.error = error.localizedDescription
            HapticFeedbackManager.shared.error()
        }
    }

    func refreshConnections() {
        refreshDisplayedConnections()
    }

    // MARK: - Connection Pool

    func prefetchConnectionPool(for node: Node) async {
        isLoadingConnections = true
        defer { isLoadingConnections = false }
        connectionPool = (try? await pipeline.discoverConnections(for: node)) ?? []
        refreshDisplayedConnections()
    }

    private func refreshDisplayedConnections() {
        // Ensure representation of all three tiers if available
        let blue = connectionPool.filter { $0.tier == .closelyRelated }
        let yellow = connectionPool.filter { $0.tier == .unexpectedAngle }
        let red = connectionPool.filter { $0.tier == .rabbitHole }

        var selected: [ScoredConnection] = []
        selected += blue.prefix(2)
        selected += yellow.prefix(2)
        selected += red.prefix(2)

        // Fill remaining slots from the pool
        let usedTitles = Set(selected.map(\.title))
        let remaining = connectionPool.filter { !usedTitles.contains($0.title) }
        selected += remaining.prefix(displaySize - selected.count)

        connectionCandidates = selected.shuffled()
    }
}
