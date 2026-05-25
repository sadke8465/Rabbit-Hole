import SwiftUI
import SwiftData

struct DiveView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let dive: Dive
    @State private var viewModel: DiveViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    diveContent(vm: vm)
                } else {
                    ProgressView("Loading dive…")
                }
            }
            .navigationTitle(dive.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if let vm = viewModel {
                        Button {
                            HapticFeedbackManager.shared.selection()
                            vm.refreshConnections()
                        } label: {
                            Image(systemName: "shuffle")
                        }
                    }
                }
            }
        }
        .task {
            let vm = DiveViewModel(modelContext: modelContext)
            viewModel = vm
            if let seedStep = dive.trail.sorted(by: { $0.position < $1.position }).first,
               let seedNode = seedStep.node {
                vm.currentNode = seedNode
                await vm.prefetchConnectionPool(for: seedNode)
            } else {
                await vm.startDive(title: dive.seedNodeID, diveName: dive.name, modelContext: modelContext)
            }
        }
    }

    @ViewBuilder
    private func diveContent(vm: DiveViewModel) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                if let node = vm.currentNode {
                    NodeStoryView(node: node, isLoading: vm.isLoadingNode)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                }

                Divider()
                    .padding(.vertical, 24)
                    .padding(.horizontal, 20)

                if vm.isLoadingConnections {
                    connectionLoadingPlaceholders
                } else {
                    connectionsSection(vm: vm)
                }
            }
        }
    }

    private var connectionLoadingPlaceholders: some View {
        VStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 90)
                    .shimmer()
                    .padding(.horizontal, 20)
            }
        }
    }

    private func connectionsSection(vm: DiveViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Where to next?")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            ForEach(vm.connectionCandidates, id: \.title) { connection in
                ConnectionCardView(connection: connection) {
                    Task { await vm.navigate(to: connection, modelContext: modelContext) }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 40)
    }
}
