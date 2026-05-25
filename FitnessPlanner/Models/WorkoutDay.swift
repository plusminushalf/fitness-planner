import Foundation
import SwiftData

@Model
final class WorkoutDay {
    var date: Date
    var completedAt: Date?
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
