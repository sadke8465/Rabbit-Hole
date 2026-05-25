import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<DailySurfaceCard> { !$0.isDismissed }) private var surfaceCards: [DailySurfaceCard]
    @Query(filter: #Predicate<Dive> { !$0.isArchived }, sort: \Dive.lastActiveAt, order: .reverse) private var dives: [Dive]
    @State private var viewModel: HomeViewModel?
    @State private var activeDive: Dive?
    @State private var showingNewDive = false
    @State private var showingGraph = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection
                    dailySurfaceSection
                    divesSection
                }
                .padding(.bottom, 32)
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
            .sheet(isPresented: $showingNewDive) {
                NewDiveView()
            }
            .sheet(isPresented: $showingGraph) {
                GraphView()
            }
            .sheet(item: $activeDive) { dive in
                DiveView(dive: dive)
            }
        }
        .task {
            let vm = HomeViewModel(modelContext: modelContext)
            viewModel = vm
            await vm.loadDailyCards(existingCards: surfaceCards)
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Rabbit Hole")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showingGraph = true
            } label: {
                Image(systemName: "circle.hexagongrid")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 24)
    }

    private var dailySurfaceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let vm = viewModel, vm.isLoadingCards {
                loadingPlaceholder
            } else {
                let todayCards = surfaceCards.filter { Calendar.current.isDateInToday($0.generatedAt) }
                if !todayCards.isEmpty {
                    sectionHeader("Today")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(todayCards) { card in
                                DailySurfaceCardView(card: card, onTap: { handleCardTap(card) })
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
        .padding(.bottom, 32)
    }

    private var divesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("Dives")
                Spacer()
                Button {
                    showingNewDive = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("New")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                }
                .padding(.trailing, 20)
            }

            if dives.isEmpty {
                emptyDivesPrompt
            } else {
                ForEach(dives) { dive in
                    DiveRowView(dive: dive)
                        .onTapGesture {
                            HapticFeedbackManager.shared.light()
                            activeDive = dive
                        }
                        .padding(.horizontal, 20)
                }
            }
        }
    }

    private var emptyDivesPrompt: some View {
        VStack(spacing: 16) {
            Text("Start a dive")
                .font(.title3.weight(.semibold))
            Text("Pick any topic and follow it wherever it leads.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Begin") {
                showingNewDive = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private var loadingPlaceholder: some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 240, height: 120)
                    .shimmer()
            }
        }
        .padding(.horizontal, 20)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .padding(.horizontal, 20)
    }

    // MARK: - Actions

    private func handleCardTap(_ card: DailySurfaceCard) {
        HapticFeedbackManager.shared.light()
        card.isTapped = true
        if let diveID = card.relatedDiveID,
           let dive = dives.first(where: { $0.id == diveID }) {
            activeDive = dive
        }
    }

    private var formattedDate: String {
        Date().formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
}
