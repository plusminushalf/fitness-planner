import Foundation
import SwiftData

@Model
final class WorkoutDay {
    var date: Date
    var completedAt: Date?
    /// When the session was started (first "Start workout" or first checked set).
    var startedAt: Date?
    /// Session length frozen at finish, so editing a past workout later doesn't change it.
    var durationSeconds: Int?
    /// Optional name, e.g. the routine it was started from. Falls back to the weekday.
    var title: String?
    /// True when the day was created in the app (empty workout, routine) rather than by a CSV.
    var isManual: Bool?
    var plan: WorkoutPlan?

    @Relationship(deleteRule: .cascade, inverse: \PlannedExercise.day)
    var exercises: [PlannedExercise] = []

    init(date: Date, completedAt: Date? = nil) {
        self.date = date
        self.completedAt = completedAt
    }

    var displayName: String {
        let df = DateFormatter()
        df.dateFormat = "EEE, MMM d"
        df.locale = .current
        return df.string(from: date)
    }
}
