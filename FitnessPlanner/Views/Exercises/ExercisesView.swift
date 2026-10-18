import SwiftUI
import SwiftData

// MARK: - Library model (shared with the picker)

/// One exercise in the library: either something the user has logged, a catalog entry, or both.
struct ExerciseLibraryEntry: Identifiable {
    let key: String
    let name: String
    let muscle: MuscleGroup
    /// Most recent logged session, nil for catalog-only entries.
    let latest: ExerciseSession?
    let catalog: CatalogExercise?

    var id: String { key }
    var isPerformed: Bool { latest != nil }
    var videoID: String? { latest?.exercise.videoID }

    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return true }
        return name.localizedCaseInsensitiveContains(q)
            || muscle.displayName.localizedCaseInsensitiveContains(q)
    }

    /// The spec to add to a workout or routine. Logged exercises carry their plan settings
    /// (rest, video, notes) but not the old weight: PREVIOUS shows that on the row anyway.
    var spec: ExerciseSpec {
        if let latest {
            var s = ExerciseSpec(exercise: latest.exercise)
            s.targetWeight = nil
            return s
        }
        if let catalog { return ExerciseSpec(catalog: catalog) }
        return ExerciseSpec(name: name, muscleGroup: muscle)
    }

    static func library(from index: ExerciseHistoryIndex) -> [ExerciseLibraryEntry] {
        var byKey: [String: ExerciseLibraryEntry] = [:]
        for key in index.allKeys {
            guard let latest = index.sessionsByKey[key]?.first else { continue }
            byKey[key] = ExerciseLibraryEntry(
                key: key,
                name: latest.exercise.name,
                muscle: latest.exercise.muscle,
                latest: latest,
                catalog: ExerciseCatalog.entry(named: latest.exercise.name)
            )
        }
        for entry in ExerciseCatalog.all where byKey[entry.id] == nil {
            byKey[entry.id] = ExerciseLibraryEntry(
                key: entry.id,
                name: entry.name,
                muscle: entry.muscle,
                latest: nil,
                catalog: entry
            )
        }
        return byKey.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

/// Horizontal muscle-group capsules. Nil selection means "All".
struct MuscleFilterBar: View {
    @Binding var selection: MuscleGroup?
    let available: [MuscleGroup]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", isSelected: selection == nil) { selection = nil }
                ForEach(available) { group in
                    chip(group.displayName, isSelected: selection == group) {
                        selection = selection == group ? nil : group
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    private func chip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 14)
                .frame(minHeight: 34)
                .background(isSelected ? Color.brand : Color.fieldFill, in: Capsule())
                .frame(minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ExerciseRoute: Hashable {
    let name: String
}

// MARK: - Exercises tab

struct ExercisesView: View {
    @Query private var days: [WorkoutDay]

    @State private var search = ""
    @State private var scope: Scope = .performed
    @State private var muscle: MuscleGroup?

    private enum Scope: String, CaseIterable, Identifiable {
        case performed = "Performed"
        case all = "Library"
        var id: String { rawValue }
    }

    private var library: [ExerciseLibraryEntry] {
        ExerciseLibraryEntry.library(from: ExerciseHistoryIndex(days: days))
    }

    var body: some View {
        let library = self.library
        let scoped = scope == .performed
            ? library.filter(\.isPerformed).sorted { ($0.latest?.date ?? .distantPast) > ($1.latest?.date ?? .distantPast) }
            : library
        let available = MuscleGroup.allCases.filter { g in scoped.contains { $0.muscle == g } }
        let visible = scoped.filter { (muscle == nil || $0.muscle == muscle) && $0.matches(search) }

        NavigationStack {
            List {
                Section {
                    Picker("Show", selection: $scope) {
                        ForEach(Scope.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowSeparator(.hidden)

                    if !available.isEmpty {
                        MuscleFilterBar(selection: $muscle, available: available)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                            .listRowSeparator(.hidden)
                    }
                }

                Section {
                    ForEach(visible) { entry in
                        NavigationLink(value: ExerciseRoute(name: entry.name)) {
                            ExerciseLibraryRow(entry: entry)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if visible.isEmpty {
                    if !search.trimmingCharacters(in: .whitespaces).isEmpty {
                        ContentUnavailableView.search(text: search)
                    } else if scope == .performed && scoped.isEmpty {
                        ContentUnavailableView {
                            Label("Nothing logged yet", systemImage: "dumbbell")
                        } description: {
                            Text("Exercises show up here once you check off a set.")
                        } actions: {
                            Button("Browse the library") { scope = .all }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
            .navigationTitle("Exercises")
            .searchable(text: $search, prompt: "Search exercises")
            .navigationDestination(for: ExerciseRoute.self) { route in
                ExerciseProgressView(name: route.name)
            }
            .onChange(of: scope) { _, _ in muscle = nil }
        }
    }
}

private struct ExerciseLibraryRow: View {
    let entry: ExerciseLibraryEntry

    var body: some View {
        HStack(spacing: 12) {
            ExerciseAvatar(name: entry.name, videoID: entry.videoID, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        guard let latest = entry.latest else { return entry.muscle.displayName }
        var parts = [entry.muscle.displayName]
        if let best = latest.bestSet {
            parts.append("Last: \(Fmt.set(best, timeBased: latest.isTimeBased))")
        }
        parts.append(Fmt.relative(latest.date))
        return parts.joined(separator: " · ")
    }
}

#Preview {
    ExercisesView()
        .modelContainer(for: [
            WorkoutPlan.self, WorkoutDay.self, PlannedExercise.self, LoggedSet.self,
            Routine.self, RoutineExercise.self,
        ], inMemory: true)
}
