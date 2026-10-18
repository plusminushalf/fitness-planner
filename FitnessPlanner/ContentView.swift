import SwiftUI
import SwiftData

/// Three sections, Hevy-style: log today, look back, see each lift's progress.
struct ContentView: View {
    @State private var tab = ContentView.initialTab

    var body: some View {
        TabView(selection: $tab) {
            WorkoutHomeView()
                .tabItem { Label("Workout", systemImage: "dumbbell.fill") }
                .tag(0)
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(1)
            ExercisesView()
                .tabItem { Label("Exercises", systemImage: "chart.xyaxis.line") }
                .tag(2)
        }
        .tint(Color.brand)
    }

    private static var initialTab: Int {
        #if DEBUG
        return UserDefaults.standard.integer(forKey: "demoTab")
        #else
        return 0
        #endif
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            WorkoutPlan.self, WorkoutDay.self, PlannedExercise.self, LoggedSet.self,
            Routine.self, RoutineExercise.self,
        ], inMemory: true)
}
