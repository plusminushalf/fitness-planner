import Foundation
import SwiftData

enum WorkoutSection: String, CaseIterable, Identifiable {
    case warmup
    case exercise
    case cooldown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .warmup: return "Warmup"
        case .exercise: return "Exercises"
        case .cooldown: return "Cooldown"
        }
    }

    var orderIndex: Int {
        switch self {
        case .warmup: return 0
        case .exercise: return 1
        case .cooldown: return 2
        }
    }
}

@Model
final class PlannedExercise {
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
    /// Raw `MuscleGroup`, set when the user picks one. Otherwise it's inferred from the name.
    var muscleGroup: String?
    var day: WorkoutDay?

    @Relationship(deleteRule: .cascade, inverse: \LoggedSet.exercise)
    var sets: [LoggedSet] = []

    init(
        name: String,
        orderIndex: Int,
        section: WorkoutSection = .exercise,
        targetSets: Int? = nil,
        targetReps: String? = nil,
        targetWeight: Double? = nil,
        durationSeconds: Int? = nil,
        restSeconds: Int? = nil,
        videoURL: String? = nil,
        notes: String? = nil,
        muscleGroup: String? = nil
    ) {
        self.name = name
        self.orderIndex = orderIndex
        self.section = section.rawValue
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.durationSeconds = durationSeconds
        self.restSeconds = restSeconds
        self.videoURL = videoURL
        self.notes = notes
        self.muscleGroup = muscleGroup
    }

    var workoutSection: WorkoutSection {
        WorkoutSection(rawValue: section) ?? .exercise
    }

    var isTimeBased: Bool {
        durationSeconds != nil
    }
}
