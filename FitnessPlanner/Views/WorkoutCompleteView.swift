import SwiftUI
import SwiftData

struct WorkoutCompleteView: View {
    let day: WorkoutDay
    let onDone: () -> Void

    private var orderedExercises: [PlannedExercise] {
        let grouped = Dictionary(grouping: day.exercises) { $0.workoutSection }
        return WorkoutSection.allCases.flatMap { section -> [PlannedExercise] in
            (grouped[section] ?? []).sorted { $0.orderIndex < $1.orderIndex }
        }
    }

    private var totalDuration: Int {
        orderedExercises.reduce(0) { acc, ex in
            acc + (ex.durationSeconds ?? 0)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.green)
                        .padding(.top, 40)

                    Text("Workout complete!")
                        .font(.largeTitle.bold())

                    Text("Great work — every exercise marked done.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    if totalDuration > 0 {
                        VStack(spacing: 2) {
                            Text("Timed work")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatDuration(totalDuration))
                                .font(.title2.bold().monospacedDigit())
                        }
                    }

                    VStack(spacing: 8) {
                        ForEach(orderedExercises) { exercise in
                            row(for: exercise)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .padding(.bottom, 24)
            }

            Button {
                onDone()
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.horizontal)
            .padding(.bottom, 24)
            .padding(.top, 8)
            .background(.regularMaterial)
        }
    }

    private func row(for exercise: PlannedExercise) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.body.weight(.medium))
                Text(detail(for: exercise))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 8))
    }

    private func detail(for exercise: PlannedExercise) -> String {
        if let secs = exercise.durationSeconds {
            return formatDuration(secs)
        }
        let completedSets = exercise.sets.filter { $0.completedAt != nil }
        let setCount = completedSets.count
        let maxWeight = completedSets.map(\.weight).max() ?? 0
        let maxReps = completedSets.map(\.reps).max() ?? 0
        let setLabel = setCount == 1 ? "set" : "sets"
        if maxWeight > 0 {
            return "\(setCount) \(setLabel) · top \(maxWeight.formatted(.number.precision(.fractionLength(0...2)))) kg × \(maxReps)"
        }
        if setCount > 0 {
            return "\(setCount) \(setLabel) × \(maxReps) reps"
        }
        return "Completed"
    }
}
