import Foundation
import SwiftData

enum CSVImporter {
    enum ImportError: LocalizedError {
        case fileReadFailed(String)
        case notUTF8
        case missingColumns([String])
        case invalidRow(line: Int, reason: String)
        case invalidVideoURL(line: Int, url: String)
        case noExercises

        var errorDescription: String? {
            switch self {
            case .fileReadFailed(let msg): return "Couldn't read the file: \(msg)"
            case .notUTF8: return "File is not valid UTF-8."
            case .missingColumns(let cols): return "CSV is missing required columns: \(cols.joined(separator: ", "))."
            case .invalidRow(let line, let reason): return "Row \(line): \(reason)."
            case .invalidVideoURL(let line, let url): return "Row \(line): video_url \"\(url)\" is not a recognizable YouTube link."
            case .noExercises: return "CSV contained no exercises."
            }
        }
    }

    private static let requiredColumns = ["date", "exercise"]

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "UTC")
        return df
    }()

    /// Imports a CSV from a file URL, replacing any existing plan in the context.
    static func importCSV(from url: URL, into context: ModelContext) throws {
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ImportError.fileReadFailed(error.localizedDescription)
        }

        guard let content = String(data: data, encoding: .utf8) else {
            throw ImportError.notUTF8
        }

        let planName = url.deletingPathExtension().lastPathComponent
        try importContent(content, planName: planName, into: context)
    }

    /// Imports CSV text directly. Exposed for tests and the sample-data path.
    static func importContent(_ csv: String, planName: String, into context: ModelContext) throws {
        let parsed = CSVParser.parse(csv)
        let dataRows = parsed.compactMap { row -> [String: String]? in
            if case .data(let d) = row { return d } else { return nil }
        }
        guard let firstData = dataRows.first else { throw ImportError.noExercises }

        let presentColumns = Set(firstData.keys)
        let missing = requiredColumns.filter { !presentColumns.contains($0) }
        if !missing.isEmpty { throw ImportError.missingColumns(missing) }

        let plan = WorkoutPlan(name: planName)
        context.insert(plan)

        var dayMap: [Date: WorkoutDay] = [:]
        var currentSection: WorkoutSection = .exercise
        var dataRowIndex = 0

        for token in parsed {
            switch token {
            case .sectionHeader(let section):
                currentSection = section
            case .data(let row):
                dataRowIndex += 1
                // Line number can only be approximated when block headers are interleaved;
                // we surface the 1-indexed data-row position which is unambiguous to the author.
                let line = dataRowIndex + 1 // +1 for header

                let dateStr = (row["date"] ?? "").trimmingCharacters(in: .whitespaces)
                guard !dateStr.isEmpty else {
                    throw ImportError.invalidRow(line: line, reason: "date is empty")
                }
                guard let date = dateFormatter.date(from: dateStr) else {
                    throw ImportError.invalidRow(line: line, reason: "date \"\(dateStr)\" is not yyyy-MM-dd")
                }

                let exerciseName = (row["exercise"] ?? "").trimmingCharacters(in: .whitespaces)
                guard !exerciseName.isEmpty else {
                    throw ImportError.invalidRow(line: line, reason: "exercise is empty")
                }

                let setsStr = (row["sets"] ?? "").trimmingCharacters(in: .whitespaces)
                let repsStr = (row["target_reps"] ?? "").trimmingCharacters(in: .whitespaces)
                let weightStr = (row["target_weight"] ?? "").trimmingCharacters(in: .whitespaces)
                let durationStr = (row["duration_seconds"] ?? "").trimmingCharacters(in: .whitespaces)
                let restStr = (row["rest_seconds"] ?? "").trimmingCharacters(in: .whitespaces)

                let restSeconds: Int?
                if restStr.isEmpty {
                    restSeconds = nil
                } else {
                    guard let secs = Int(restStr), secs > 0 else {
                        throw ImportError.invalidRow(line: line, reason: "rest_seconds must be a positive integer (got \"\(restStr)\")")
                    }
                    restSeconds = secs
                }

                let durationSeconds: Int?
                let targetSets: Int?
                let targetReps: String?
                let targetWeight: Double?

                if !durationStr.isEmpty {
                    // Time-based: reject any weight/reps fields to keep semantics unambiguous.
                    if !setsStr.isEmpty || !repsStr.isEmpty || !weightStr.isEmpty {
                        throw ImportError.invalidRow(line: line, reason: "time-based exercise must leave sets/target_reps/target_weight empty")
                    }
                    guard let secs = Int(durationStr), secs > 0 else {
                        throw ImportError.invalidRow(line: line, reason: "duration_seconds must be a positive integer (got \"\(durationStr)\")")
                    }
                    durationSeconds = secs
                    targetSets = nil
                    targetReps = nil
                    targetWeight = nil
                } else {
                    // Weight-based: sets + target_reps are required.
                    guard !setsStr.isEmpty, let sets = Int(setsStr), sets > 0 else {
                        throw ImportError.invalidRow(line: line, reason: "sets must be a positive integer (got \"\(setsStr)\")")
                    }
                    guard !repsStr.isEmpty else {
                        throw ImportError.invalidRow(line: line, reason: "target_reps is required for weight-based exercises")
                    }
                    let parsedWeight: Double? = weightStr.isEmpty ? nil : Double(weightStr)
                    if !weightStr.isEmpty && parsedWeight == nil {
                        throw ImportError.invalidRow(line: line, reason: "target_weight is not a number (got \"\(weightStr)\")")
                    }
                    durationSeconds = nil
                    targetSets = sets
                    targetReps = repsStr
                    targetWeight = parsedWeight
                }

                let rawVideo = optional(row["video_url"])
                if let raw = rawVideo, YouTubeURL.videoID(from: raw) == nil {
                    throw ImportError.invalidVideoURL(line: line, url: raw)
                }
                let notes = optional(row["notes"])

                let day: WorkoutDay
                if let existing = dayMap[date] {
                    day = existing
                } else {
                    day = WorkoutDay(date: date)
                    day.plan = plan
                    dayMap[date] = day
                    context.insert(day)
                }

                let exercise = PlannedExercise(
                    name: exerciseName,
                    orderIndex: day.exercises.count,
                    section: currentSection,
                    targetSets: targetSets,
                    targetReps: targetReps,
                    targetWeight: targetWeight,
                    durationSeconds: durationSeconds,
                    restSeconds: restSeconds,
                    videoURL: rawVideo,
                    notes: notes
                )
                exercise.day = day
                context.insert(exercise)

                if let secs = durationSeconds {
                    let set = LoggedSet(setNumber: 1, durationSeconds: secs)
                    set.exercise = exercise
                    context.insert(set)
                } else {
                    for n in 1...max(1, targetSets ?? 1) {
                        let set = LoggedSet(setNumber: n)
                        set.exercise = exercise
                        context.insert(set)
                    }
                }
            }
        }

        if dayMap.isEmpty { throw ImportError.noExercises }
    }

    private static func optional(_ raw: String?) -> String? {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}
