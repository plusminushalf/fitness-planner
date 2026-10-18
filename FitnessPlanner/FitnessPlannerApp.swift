import SwiftUI
import SwiftData

@main
struct FitnessPlannerApp: App {
    let container: ModelContainer

    init() {
        WebViewWarmup.warm()

        let schema = Schema([
            WorkoutPlan.self,
            WorkoutDay.self,
            PlannedExercise.self,
            LoggedSet.self,
            Routine.self,
            RoutineExercise.self,
        ])
        let config = ModelConfiguration(schema: schema)
        if let c = try? ModelContainer(for: schema, configurations: [config]) {
            self.container = c
        } else {
            // Schema mismatch from a previous version: drop the store and retry.
            // Acceptable because the canonical source of plans is the user's CSV.
            Self.deleteDefaultStore()
            self.container = (try? ModelContainer(for: schema, configurations: [config]))
                ?? Self.makeInMemoryContainer(schema: schema)
        }
    }

    var body: some Scene {
        #if DEBUG
        let _ = DemoData.seedIfRequested(into: container.mainContext)
        #endif
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }

    private static func deleteDefaultStore() {
        let fm = FileManager.default
        guard let appSupport = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return }
        for suffix in ["default.store", "default.store-shm", "default.store-wal"] {
            let url = appSupport.appendingPathComponent(suffix)
            try? fm.removeItem(at: url)
        }
    }

    private static func makeInMemoryContainer(schema: Schema) -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        // If this still fails, we'd rather crash than launch into undefined state.
        return try! ModelContainer(for: schema, configurations: [config])
    }
}
