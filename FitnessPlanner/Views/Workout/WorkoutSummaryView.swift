import SwiftUI
import SwiftData

/// Shown once when a workout is finished: the numbers, the records, and what was done.
struct WorkoutSummaryView: View {
    let day: WorkoutDay
    let summary: WorkoutSummary
    let onDone: () -> Void

    @State private var appeared = false

    private var performed: [PlannedExercise] {
        day.orderedExercises.filter { !$0.completedSets.isEmpty }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: summary.records.isEmpty ? "checkmark.seal.fill" : "trophy.fill")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(summary.records.isEmpty ? Color.doneGreen : Color.recordGold)
                            .symbolEffect(.bounce, value: appeared)
                            .padding(.bottom, 6)
                        Text("Workout complete")
                            .font(.largeTitle.weight(.bold))
                        Text(ordinalLine)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 32)

                    HStack(spacing: 12) {
                        StatPair(label: "Duration", value: day.elapsedSeconds().map(Fmt.elapsed) ?? "–")
                        StatPair(label: "Volume", value: Fmt.volume(day.volume))
                        StatPair(label: "Sets", value: "\(day.completedSetCount)")
                        StatPair(
                            label: "Records",
                            value: "\(summary.records.count)",
                            valueColor: summary.records.isEmpty ? .primary : .recordGold
                        )
                    }
                    .card()

                    if !summary.records.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Personal records")
                                .font(.headline)
                            ForEach(summary.records) { hit in
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
                                    Spacer()
                                    Text(hit.kind.format(hit.value))
                                        .font(.subheadline.weight(.semibold).monospacedDigit())
                                }
                            }
                        }
                        .card()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Exercises")
                            .font(.headline)
                        ForEach(performed) { exercise in
                            let session = ExerciseSession(exercise: exercise, day: day, sets: exercise.completedSets)
                            HStack(spacing: 12) {
                                ExerciseAvatar(name: exercise.name, videoID: exercise.videoID, size: 36)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(exercise.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(session.sets.count) \(session.sets.count == 1 ? "set" : "sets")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let best = session.bestSet {
                                    Text(Fmt.set(best, timeBased: exercise.isTimeBased))
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .card()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }

            Button("Done", action: onDone)
                .buttonStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(.bar)
        }
        .background(Color.screenFill)
        .sensoryFeedback(.success, trigger: appeared)
        .onAppear { appeared = true }
    }

    private var ordinalLine: String {
        let n = summary.workoutNumber
        let f = NumberFormatter()
        f.numberStyle = .ordinal
        let ordinal = f.string(from: NSNumber(value: n)) ?? "\(n)"
        return "\(day.displayTitle) · your \(ordinal) logged workout."
    }
}
