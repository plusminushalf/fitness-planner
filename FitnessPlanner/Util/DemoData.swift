#if DEBUG
import Foundation
import SwiftData

/// Synthetic data for simulator checks. Launch with `-seedDemo YES` on an empty store:
/// this week's sample plan plus six weeks of made-up completed sessions behind it.
enum DemoData {
    static func seedIfRequested(into context: ModelContext) {
        guard UserDefaults.standard.bool(forKey: "seedDemo") else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<WorkoutPlan>())) ?? 0
        guard existing == 0 else { return }

        let cal = Calendar.current
        let monday = cal.startOfDay(for: .now) // the sample's first day lands on today
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "UTC")

        // Shift the sample week (2026-05-25 …) so it starts today.
        // The simulator can read the repo directly; nothing extra ships in the bundle.
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("sample-plans/sample-week.csv")
        guard var csv = try? String(contentsOf: url, encoding: .utf8) else { return }
        for offset in 0..<7 {
            let original = df.string(from: df.date(from: "2026-05-25")!.addingTimeInterval(Double(offset) * 86_400))
            let target = df.string(from: cal.date(byAdding: .day, value: offset, to: monday)!)
            csv = csv.replacingOccurrences(of: original, with: target)
        }
        try? CSVImporter.importContent(csv, planName: "Sample week", into: context)
        let plan = try? context.fetch(FetchDescriptor<WorkoutPlan>()).first

        // Six earlier weeks of the same sessions, a little lighter the further back.
        let templates = plan?.days ?? []
        for weeksBack in 1...6 {
            for template in templates {
                guard let date = cal.date(byAdding: .day, value: -7 * weeksBack, to: template.date) else { continue }
                let day = WorkoutDay(date: date)
                day.plan = plan
                day.isManual = true
                let start = cal.date(bySettingHour: 18, minute: 10, second: 0, of: date) ?? date
                day.startedAt = start
                day.durationSeconds = 3_000 + weeksBack * 120
                day.completedAt = start.addingTimeInterval(TimeInterval(day.durationSeconds ?? 0))
                context.insert(day)
                for exercise in template.orderedExercises {
                    let copy = PlannedExercise(
                        name: exercise.name, orderIndex: exercise.orderIndex, section: exercise.workoutSection,
                        targetSets: exercise.targetSets, targetReps: exercise.targetReps, targetWeight: exercise.targetWeight,
                        durationSeconds: exercise.durationSeconds, restSeconds: exercise.restSeconds,
                        videoURL: exercise.videoURL, notes: exercise.notes
                    )
                    copy.day = day
                    context.insert(copy)
                    let count = exercise.isTimeBased ? 1 : (exercise.targetSets ?? 3)
                    for n in 1...count {
                        let set = LoggedSet(setNumber: n)
                        if exercise.isTimeBased {
                            set.durationSeconds = exercise.durationSeconds
                        } else {
                            let base = exercise.targetWeight ?? 0
                            set.weight = (base * (1 - 0.03 * Double(weeksBack)) / 2.5).rounded() * 2.5
                            let reps = Int(exercise.targetReps?.prefix { $0.isNumber } ?? "") ?? 8
                            set.reps = reps + (n == 1 ? 1 : 0)
                        }
                        set.completedAt = day.startedAt?.addingTimeInterval(Double(n) * 180)
                        set.exercise = copy
                        context.insert(set)
                    }
                }
            }
        }

        let routine = Routine(name: "Upper Body A")
        context.insert(routine)
        WorkoutFactory.replaceExercises(of: routine, with: [
            ExerciseSpec(name: "Bench Press", targetSets: 4, targetReps: "6-8", targetWeight: 80, restSeconds: 120),
            ExerciseSpec(name: "Pull-up", targetSets: 4, targetReps: "5-8", restSeconds: 120),
            ExerciseSpec(name: "Overhead Press", targetSets: 3, targetReps: "8", targetWeight: 50, restSeconds: 90),
            ExerciseSpec(name: "Lateral Raise", targetSets: 3, targetReps: "12-15", targetWeight: 8, restSeconds: 60),
        ], context: context)
        try? context.save()
    }
}
#endif
