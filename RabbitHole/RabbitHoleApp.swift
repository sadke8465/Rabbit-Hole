import SwiftUI
import SwiftData

@main
struct RabbitHoleApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for:
                Node.self,
                Connection.self,
                Dive.self,
                TrailStep.self,
                DailySurfaceCard.self,
                UserSettings.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .modelContainer(modelContainer)
        }
    }
}

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]

    var body: some View {
        HomeView()
            .onAppear { ensureUserSettings() }
    }

    private func ensureUserSettings() {
        if settings.isEmpty {
            modelContext.insert(UserSettings())
            try? modelContext.save()
        }
    }
}
