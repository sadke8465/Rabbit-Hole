import Foundation
import SwiftUI
import Observation

struct GraphNode: Identifiable {
    let id: String
    let title: String
    var position: CGPoint
    var isCurrentNode: Bool
    var visitCount: Int
}

struct GraphEdge: Identifiable {
    let id: UUID
    let sourceID: String
    let targetID: String
    let tier: ConnectionTier
    let isTrailEdge: Bool   // Part of the user's actual trail
}

@Observable
final class GraphViewModel {
    var nodes: [GraphNode] = []
    var edges: [GraphEdge] = []
    var selectedNodeID: String?
    var scale: CGFloat = 1.0
    var offset: CGSize = .zero

    func buildGraph(from allNodes: [Node], dives: [Dive]) {
        // Layout nodes using force-directed algorithm approximation
        var graphNodes: [GraphNode] = []
        var graphEdges: [GraphEdge] = []

        let trailNodeIDs = dives.flatMap { $0.trail.compactMap { $0.node?.id } }
        let trailEdgePairs = buildTrailEdgePairs(dives: dives)

        for (index, node) in allNodes.enumerated() {
            let angle = Double(index) / Double(max(allNodes.count, 1)) * 2 * .pi
            let radius = 200.0 + Double(index % 3) * 80.0
            let position = CGPoint(
                x: cos(angle) * radius,
                y: sin(angle) * radius
            )
            graphNodes.append(GraphNode(
                id: node.id,
                title: node.title,
                position: position,
                isCurrentNode: false,
                visitCount: node.trailSteps.count
            ))

            for conn in node.outgoingConnections {
                guard let targetID = conn.targetNode?.id else { continue }
                graphEdges.append(GraphEdge(
                    id: conn.id,
                    sourceID: node.id,
                    targetID: targetID,
                    tier: conn.tier,
                    isTrailEdge: trailEdgePairs.contains("\(node.id)→\(targetID)")
                ))
            }
        }

        nodes = graphNodes
        edges = graphEdges
        _ = trailNodeIDs // used for styling in the view layer
    }

    func applyForceLayout(iterations: Int = 50) {
        guard nodes.count > 1 else { return }
        let repulsion: CGFloat = 8000
        let attraction: CGFloat = 0.05
        let damping: CGFloat = 0.85

        var velocities = [String: CGVector](uniqueKeysWithValues: nodes.map { ($0.id, .zero) })

        for _ in 0..<iterations {
            var forces = [String: CGVector](uniqueKeysWithValues: nodes.map { ($0.id, .zero) })

            // Repulsion between all nodes
            for i in 0..<nodes.count {
                for j in (i + 1)..<nodes.count {
                    let dx = nodes[i].position.x - nodes[j].position.x
                    let dy = nodes[i].position.y - nodes[j].position.y
                    let dist = max(sqrt(dx * dx + dy * dy), 1)
                    let force = repulsion / (dist * dist)
                    let fx = (dx / dist) * force
                    let fy = (dy / dist) * force
                    forces[nodes[i].id]?.dx += fx
                    forces[nodes[i].id]?.dy += fy
                    forces[nodes[j].id]?.dx -= fx
                    forces[nodes[j].id]?.dy -= fy
                }
            }

            // Attraction along edges
            let nodeMap = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
            for edge in edges {
                guard let src = nodeMap[edge.sourceID], let tgt = nodeMap[edge.targetID] else { continue }
                let dx = tgt.position.x - src.position.x
                let dy = tgt.position.y - src.position.y
                forces[edge.sourceID]?.dx += dx * attraction
                forces[edge.sourceID]?.dy += dy * attraction
                forces[edge.targetID]?.dx -= dx * attraction
                forces[edge.targetID]?.dy -= dy * attraction
            }

            // Update positions
            for i in 0..<nodes.count {
                let id = nodes[i].id
                velocities[id]?.dx = ((velocities[id]?.dx ?? 0) + (forces[id]?.dx ?? 0)) * damping
                velocities[id]?.dy = ((velocities[id]?.dy ?? 0) + (forces[id]?.dy ?? 0)) * damping
                nodes[i].position.x += velocities[id]?.dx ?? 0
                nodes[i].position.y += velocities[id]?.dy ?? 0
            }
        }
    }

    private func buildTrailEdgePairs(dives: [Dive]) -> Set<String> {
        var pairs = Set<String>()
        for dive in dives {
            let sorted = dive.trail.sorted { $0.position < $1.position }
            for i in 0..<(sorted.count - 1) {
                if let a = sorted[i].node?.id, let b = sorted[i + 1].node?.id {
                    pairs.insert("\(a)→\(b)")
                }
            }
        }
        return pairs
    }
}
