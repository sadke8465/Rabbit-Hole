import SwiftUI
import SwiftData

struct GraphView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var nodes: [Node]
    @Query private var dives: [Dive]
    @State private var viewModel = GraphViewModel()
    @State private var selectedNode: Node?
    @GestureState private var dragOffset: CGSize = .zero
    @State private var pinchScale: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    Color(.systemBackground).ignoresSafeArea()
                    graphCanvas(size: geo.size)
                    if let node = selectedNode {
                        nodeDetailOverlay(node: node)
                    }
                }
            }
            .navigationTitle("Your Graph")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation { viewModel.scale = 1.0; viewModel.offset = .zero }
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                }
            }
        }
        .onAppear {
            viewModel.buildGraph(from: nodes, dives: dives)
            viewModel.applyForceLayout()
        }
    }

    private func graphCanvas(size: CGSize) -> some View {
        Canvas { context, _ in
            let center = CGPoint(x: size.width / 2 + viewModel.offset.width,
                                 y: size.height / 2 + viewModel.offset.height)
            let nodeMap = Dictionary(uniqueKeysWithValues: viewModel.nodes.map { ($0.id, $0) })

            // Draw edges
            for edge in viewModel.edges {
                guard let src = nodeMap[edge.sourceID], let tgt = nodeMap[edge.targetID] else { continue }
                let from = CGPoint(
                    x: center.x + src.position.x * viewModel.scale,
                    y: center.y + src.position.y * viewModel.scale
                )
                let to = CGPoint(
                    x: center.x + tgt.position.x * viewModel.scale,
                    y: center.y + tgt.position.y * viewModel.scale
                )
                var path = Path()
                path.move(to: from)
                path.addLine(to: to)
                let edgeColor = edge.isTrailEdge
                    ? Color.primary.opacity(0.6)
                    : tierColor(for: edge.tier).opacity(0.2)
                context.stroke(path, with: .color(edgeColor), lineWidth: edge.isTrailEdge ? 1.5 : 0.8)
            }

            // Draw nodes
            for node in viewModel.nodes {
                let pos = CGPoint(
                    x: center.x + node.position.x * viewModel.scale,
                    y: center.y + node.position.y * viewModel.scale
                )
                let radius: CGFloat = min(6 + CGFloat(node.visitCount) * 2, 18) * viewModel.scale
                let isSelected = node.id == selectedNode?.id

                var circle = Path()
                circle.addEllipse(in: CGRect(
                    x: pos.x - radius, y: pos.y - radius,
                    width: radius * 2, height: radius * 2
                ))
                context.fill(circle, with: .color(isSelected ? Color.accentColor : Color.primary))

                if viewModel.scale > 0.7 {
                    let text = Text(node.title)
                        .font(.system(size: max(9, 11 * viewModel.scale)))
                        .foregroundStyle(Color.secondary)
                    context.draw(text, at: CGPoint(x: pos.x, y: pos.y + radius + 8))
                }
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    viewModel.offset = CGSize(
                        width: viewModel.offset.width + value.translation.width - (dragOffset.width),
                        height: viewModel.offset.height + value.translation.height - (dragOffset.height)
                    )
                }
        )
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    viewModel.scale = max(0.3, min(3.0, pinchScale * value.magnification))
                }
                .onEnded { value in
                    pinchScale = viewModel.scale
                }
        )
        .onTapGesture { location in
            handleTap(at: location, canvasSize: CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        }
    }

    private func handleTap(at location: CGPoint, canvasSize: CGSize) {
        let center = CGPoint(
            x: canvasSize.width / 2 + viewModel.offset.width,
            y: canvasSize.height / 2 + viewModel.offset.height
        )
        for graphNode in viewModel.nodes {
            let pos = CGPoint(
                x: center.x + graphNode.position.x * viewModel.scale,
                y: center.y + graphNode.position.y * viewModel.scale
            )
            let radius: CGFloat = 24
            if abs(location.x - pos.x) < radius && abs(location.y - pos.y) < radius {
                let node = nodes.first { $0.id == graphNode.id }
                withAnimation { selectedNode = node }
                return
            }
        }
        withAnimation { selectedNode = nil }
    }

    private func nodeDetailOverlay(node: Node) -> some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(node.title)
                        .font(.headline)
                    Spacer()
                    Button { withAnimation { selectedNode = nil } } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
                if !node.story.isEmpty {
                    Text(node.story)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            }
            .padding(20)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    private func tierColor(for tier: ConnectionTier) -> Color {
        switch tier {
        case .closelyRelated: return .blue
        case .unexpectedAngle: return .yellow
        case .rabbitHole: return .red
        }
    }
}
