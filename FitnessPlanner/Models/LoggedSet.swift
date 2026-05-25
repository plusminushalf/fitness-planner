import Foundation
import SwiftData

@Model
final class LoggedSet {
    var setNumber: Int
    var weight: Double
    var reps: Int
    var durationSeconds: Int?
    var completedAt: Date?
    var notes: String?
    var exercise: PlannedExercise?

    init(
        setNumber: Int,
        weight: Double = 0,
        reps: Int = 0,
        durationSeconds: Int? = nil,
        completedAt: Date? = nil,
        notes: String? = nil
    ) {
        self.setNumber = setNumber
        self.weight = weight
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.completedAt = completedAt
        self.notes = notes
    }
}
