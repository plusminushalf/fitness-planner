import SwiftUI
import SwiftData

/// Read-only summary of a logged workout, with Edit to reopen it in the set table.
struct WorkoutDetailView: View {
    let day: WorkoutDay

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allDays: [WorkoutDay]

    @State private var showingSaveRoutine = false
    @State private var routineName = ""
    @State private var showingDeleteConfirm = false
    @State private var toastMessage: String?

    var body: some View {
        let index = ExerciseHistoryIndex(days: allDays)
        let hits = index.recordHits(in: day)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(recordCount: hits.count)

                if !hits.isEmpty {
                    recordsCard(hits)
                }

                ForEach(day.orderedExercises.filter { !$0.completedSets.isEmpty }) { exercise in
                    ExerciseResultCard(
                        exercise: exercise,
                        prSetIDs: prSetIDs(for: exercise, index: index)
                    )
                }
            }
            .padding()
            .padding(.bottom, 16)
        }
        .background(Color.screenFill)
        .navigationTitle(day.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink("Edit") {
                    ActiveWorkoutView(day: day)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        routineName = day.displayTitle
                        showingSaveRoutine = true
                    } label: {
                        Label("Save as Routine", systemImage: "square.and.arrow.down.on.square")
                    }
                    Divider()
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Delete Workout", systemImage: "trash")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .alert("Save as routine", isPresented: $showingSaveRoutine) {
            TextField("Routine name", text: $routineName)
            Button("Save") { saveRoutine() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Uses this workout's exercises, with what you lifted as the new targets.")
        }
        .confirmationDialog(
            "Delete this workout?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(day.isManual == true ? "Delete Workout" : "Clear Logged Sets", role: .destructive) {
                deleteWorkout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(day.isManual == true
                 ? "This removes the workout and every set in it. This can't be undone."
                 : "The planned exercises stay on the schedule; only what you logged is cleared.")
        }
        .toast($toastMessage)
    }

    // MARK: - Sections

    private func header(recordCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.displayTitle)
                    .font(.title2.bold())
                Text(dateLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 8) {
                StatPair(label: "Time", value: day.elapsedSeconds().map(Fmt.elapsed) ?? "—")
                StatPair(label: "Volume", value: Fmt.volume(day.volume))
                StatPair(label: "Sets", value: "\(day.completedSetCount)")
                RecordsStat(count: recordCount)
            }
        }
        .padding(.horizontal, 4)
    }

    private func recordsCard(_ hits: [RecordHit]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(hits.count == 1 ? "1 personal record" : "\(hits.count) personal records")
                .font(.headline)
            ForEach(hits) { hit in
                HStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(Color.recordGold)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(hit.exerciseName)
                            .font(.subheadline.weight(.semibold))
                        Text(hit.kind.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Text(hit.kind.format(hit.value))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
                .accessibilityElement(children: .combine)
            }
        }
        .card()
    }

    private var dateLine: String {
        var s = Fmt.dayAndDate(day.date)
        if let started = day.startedAt {
            s += " · " + started.formatted(date: .omitted, time: .shortened)
        }
        return s
    }

    /// Sets that beat the running best at the moment they were done, against everything before this day.
    private func prSetIDs(for exercise: PlannedExercise, index: ExerciseHistoryIndex) -> Set<PersistentIdentifier> {
        var prior = index.records(for: exercise.name, before: day.date)
        guard !prior.isEmpty else { return [] }
        var ids: Set<PersistentIdentifier> = []
        for set in exercise.completedSets {
            let kinds = prior.beaten(by: set, timeBased: exercise.isTimeBased)
            guard !kinds.isEmpty else { continue }
            ids.insert(set.persistentModelID)
            for kind in kinds {
                let value: Double
                switch kind {
                case .heaviestWeight: value = set.weight
                case .bestOneRepMax: value = set.estimatedOneRepMax ?? 0
                case .bestSetVolume: value = set.volume
                case .mostReps: value = Double(set.reps)
                case .longestDuration: value = Double(set.durationSeconds ?? 0)
                }
                prior.values[kind] = max(prior.values[kind] ?? 0, value)
            }
        }
        return ids
    }

    // MARK: - Actions

    private func saveRoutine() {
        let name = routineName.trimmingCharacters(in: .whitespacesAndNewlines)
        WorkoutFactory.makeRoutine(from: day, name: name.isEmpty ? day.displayTitle : name, context: context)
        try? context.save()
        toastMessage = "Routine saved"
    }

    private func deleteWorkout() {
        let target = day
        let isManual = target.isManual == true
        dismiss()
        // Let the pop finish before mutating, so this view never renders a deleted model.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            if isManual {
                context.delete(target)
            } else {
                for exercise in target.exercises {
                    for set in exercise.sets {
                        set.completedAt = nil
                        if !exercise.isTimeBased {
                            set.weight = 0
                            set.reps = 0
                        }
                    }
                }
                target.completedAt = nil
                target.startedAt = nil
                target.durationSeconds = nil
            }
            try? context.save()
        }
    }
}

// MARK: - Exercise result

private struct ExerciseResultCard: View {
    let exercise: PlannedExercise
    let prSetIDs: Set<PersistentIdentifier>

    private var rows: [(set: LoggedSet, label: String)] {
        var counter = 0
        return exercise.completedSets.map { set in
            if set.kind != .warmup { counter += 1 }
            return (set, set.kind.badge ?? "\(counter)")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ExerciseAvatar(name: exercise.name, videoID: exercise.videoID, size: 36)
                Text(exercise.name)
                    .font(.headline)
                    .foregroundStyle(Color.brand)
                    .lineLimit(2)
            }

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    ColumnLabel("Set").frame(width: 44)
                    ColumnLabel(exercise.isTimeBased ? "Time" : "Weight & reps")
                }
                .padding(.bottom, 6)

                ForEach(Array(rows.enumerated()), id: \.element.set.persistentModelID) { i, row in
                    HStack(spacing: 8) {
                        Text(row.label)
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(row.set.kind == .normal ? Color.secondary : row.set.kind.tint)
                            .frame(width: 44, alignment: .leading)
                        Text(Fmt.set(row.set, timeBased: exercise.isTimeBased))
                            .font(.subheadline.monospacedDigit())
                        Spacer(minLength: 8)
                        if prSetIDs.contains(row.set.persistentModelID) {
                            Image(systemName: "trophy.fill")
                                .font(.caption)
                                .foregroundStyle(Color.recordGold)
                                .accessibilityLabel("Personal record")
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                    .background(
                        i.isMultiple(of: 2) ? Color.fieldFill.opacity(0.5) : Color.clear,
                        in: .rect(cornerRadius: 6, style: .continuous)
                    )
                    .padding(.horizontal, -8)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .card()
    }
}
