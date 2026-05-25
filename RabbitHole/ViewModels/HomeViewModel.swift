import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class HomeViewModel {
    var dailyCards: [DailySurfaceCard] = []
    var isLoadingCards = false
    var searchQuery = ""
    var searchResults: [WikipediaSearchResult] = []
    var isSearching = false
    var activeSheet: HomeSheet?

    enum HomeSheet: Identifiable {
        case newDive
        case graphView
        case diveDetail(Dive)

        var id: String {
            switch self {
            case .newDive: return "newDive"
            case .graphView: return "graphView"
            case .diveDetail(let d): return "dive-\(d.id)"
            }
        }
    }

    private let dailySurfaceService: DailySurfaceService
    private let wikipediaService = WikipediaService()
    private var searchTask: Task<Void, Never>?

    init(modelContext: ModelContext) {
        self.dailySurfaceService = DailySurfaceService(modelContext: modelContext)
    }

    func loadDailyCards(existingCards: [DailySurfaceCard]) async {
        let todayCards = existingCards.filter {
            Calendar.current.isDateInToday($0.generatedAt) && !$0.isDismissed
        }
        if !todayCards.isEmpty {
            dailyCards = todayCards
            return
        }
        isLoadingCards = true
        defer { isLoadingCards = false }
        dailyCards = (try? await dailySurfaceService.generateDailyCards()) ?? []
    }

    func searchWikipedia(query: String) {
        searchTask?.cancel()
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000) // debounce 400ms
            guard !Task.isCancelled else { return }
            isSearching = true
            defer { isSearching = false }
            searchResults = (try? await wikipediaService.search(query: query)) ?? []
        }
    }
}
