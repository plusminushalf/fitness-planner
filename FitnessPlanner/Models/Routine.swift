import Foundation
import SwiftData

/// A reusable workout template. Starting one copies its exercises into a `WorkoutDay`.
@Model
final class Routine {
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var notes: String?

    @Relationship(deleteRule: .cascade, inverse: \RoutineExercise.routine)
    var exercises: [RoutineExercise] = []

    init(name: String, createdAt: Date = .now, notes: String? = nil) {
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.notes = notes
    }

    var orderedExercises: [RoutineExercise] {
        exercises.sorted { a, b in
            let sa = a.workoutSection.orderIndex
            let sb = b.workoutSection.orderIndex
            if sa != sb { return sa < sb }
            return a.orderIndex < b.orderIndex
        }
    }
}

@Model
final class RoutineExercise {
    var name: String
    var orderIndex: Int
    var section: String
    var targetSets: Int?
    var targetReps: String?
    var targetWeight: Double?
    var durationSeconds: Int?
    var restSeconds: Int?
    var videoURL: String?
    var notes: String?
    var muscleGroup: String?
    var routine: Routine?

    init(spec: ExerciseSpec, orderIndex: Int) {
        self.name = spec.name
        self.orderIndex = orderIndex
        self.section = spec.section.rawValue
        self.targetSets = spec.targetSets
        self.targetReps = spec.targetReps
        self.targetWeight = spec.targetWeight
        self.durationSeconds = spec.durationSeconds
        self.restSeconds = spec.restSeconds
        self.videoURL = spec.videoURL
        self.notes = spec.notes
        self.muscleGroup = spec.muscleGroup?.rawValue
    }

    var workoutSection: WorkoutSection {
        WorkoutSection(rawValue: section) ?? .exercise
    }
}
