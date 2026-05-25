import Foundation

enum CSVExporter {
    private static let header = "date,section,exercise,set_number,target_reps,target_weight,duration_seconds,actual_weight,actual_reps,actual_duration_seconds,notes"

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "UTC")
        return df
    }()

    /// Builds a CSV string from all completed sets in the plan.
    /// Only sets with `completedAt != nil` are included.
    static func makeCSV(from plan: WorkoutPlan) -> String {
        var lines: [String] = [header]

        let sortedDays = plan.days.sorted { $0.date < $1.date }
        for day in sortedDays {
            let sortedExercises = day.exercises.sorted { a, b in
                let sa = a.workoutSection.orderIndex
                let sb = b.workoutSection.orderIndex
                if sa != sb { return sa < sb }
                return a.orderIndex < b.orderIndex
            }
            for exercise in sortedExercises {
                for set in exercise.sets.sorted(by: { $0.setNumber < $1.setNumber }) {
                    guard set.completedAt != nil else { continue }
                    let dateField = dateFormatter.string(from: day.date)
                    let sectionField = exercise.workoutSection.rawValue
                    let targetRepsField = exercise.targetReps ?? ""
                    let targetWeightField = exercise.targetWeight.map(formatNumber) ?? ""
                    let durationField = exercise.durationSeconds.map(String.init) ?? ""
                    let actualWeightField = exercise.isTimeBased ? "" : formatNumber(set.weight)
                    let actualRepsField = exercise.isTimeBased ? "" : String(set.reps)
                    let actualDurationField = set.durationSeconds.map(String.init) ?? ""
                    let notesField = set.notes ?? ""
                    let fields: [String] = [
                        dateField,
                        sectionField,
                        exercise.name,
                        String(set.setNumber),
                        targetRepsField,
                        targetWeightField,
                        durationField,
                        actualWeightField,
                        actualRepsField,
                        actualDurationField,
                        notesField,
                    ]
                    lines.append(fields.map(escape).joined(separator: ","))
                }
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    /// Convenience: writes the CSV to a tmp file and returns the URL.
    static func writeToTempFile(for plan: WorkoutPlan, today: Date = .now) throws -> URL {
        let csv = makeCSV(from: plan)
        let stamp = dateFormatter.string(from: today)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("fitness-export-\(stamp).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func hasCompletedSets(in plan: WorkoutPlan) -> Bool {
        plan.days.contains { day in
            day.exercises.contains { exercise in
                exercise.sets.contains { $0.completedAt != nil }
            }
        }
    }

    private static func formatNumber(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e15 {
            return String(Int(value))
        }
        // Trim trailing zeros but allow up to 2 fractional digits.
        let s = String(format: "%.2f", value)
        return s.replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
    }

    private static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
}
