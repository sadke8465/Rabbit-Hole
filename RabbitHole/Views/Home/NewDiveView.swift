import SwiftUI

struct NewDiveView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var diveName = ""
    @State private var searchResults: [WikipediaSearchResult] = []
    @State private var isSearching = false
    @State private var selectedTitle: String?
    @State private var activeDive: ActiveDiveContext?
    private let wikipedia = WikipediaService()
    private var searchTask: Task<Void, Never>?

    struct ActiveDiveContext: Identifiable {
        let id = UUID()
        let title: String
        let diveName: String
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                if isSearching {
                    ProgressView()
                        .padding(.top, 40)
                    Spacer()
                } else if searchResults.isEmpty && !query.isEmpty {
                    ContentUnavailableView(
                        "No results",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different topic")
                    )
                } else {
                    List(searchResults, id: \.title) { result in
                        resultRow(result)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Start a Dive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .sheet(item: $activeDive) { ctx in
            DiveStartView(title: ctx.title, suggestedName: ctx.diveName, onStart: { _ in
                dismiss()
            })
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Any topic…", text: $query)
                .autocorrectionDisabled()
                .onChange(of: query) { _, new in performSearch(query: new) }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func resultRow(_ result: WikipediaSearchResult) -> some View {
        Button {
            activeDive = ActiveDiveContext(
                title: result.title,
                diveName: result.title
            )
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                if !result.description.isEmpty {
                    Text(result.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            let results = (try? await wikipedia.search(query: query)) ?? []
            await MainActor.run {
                searchResults = results
                isSearching = false
            }
        }
    }
}

struct DiveStartView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let title: String
    let suggestedName: String
    let onStart: (Dive) -> Void
    @State private var diveName: String
    @State private var isStarting = false

    init(title: String, suggestedName: String, onStart: @escaping (Dive) -> Void) {
        self.title = title
        self.suggestedName = suggestedName
        self.onStart = onStart
        _diveName = State(initialValue: suggestedName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dive Name") {
                    TextField("Name this dive", text: $diveName)
                }
                Section {
                    Text("Starting with: \(title)")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Name Your Dive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Begin") { start() }
                        .disabled(diveName.isEmpty || isStarting)
                }
            }
        }
    }

    private func start() {
        isStarting = true
        let dive = Dive(name: diveName, seedNodeID: title)
        modelContext.insert(dive)
        try? modelContext.save()
        onStart(dive)
        dismiss()
    }
}
