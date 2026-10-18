import Foundation
import SwiftData

/// How a set counts. Warm-ups are logged but never count toward records.
enum SetType: String, CaseIterable, Identifiable {
    case normal
    case warmup
    case drop
    case failure

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .normal: return "Normal set"
        case .warmup: return "Warm-up set"
        case .drop: return "Drop set"
        case .failure: return "Failure set"
        }
    }

    /// The letter shown in the SET column instead of a number. Nil for normal sets.
    var badge: String? {
        switch self {
        case .normal: return nil
        case .warmup: return "W"
        case .drop: return "D"
        case .failure: return "F"
        }
    }

    var countsTowardRecords: Bool { self != .warmup }
}

@Model
final class LoggedSet {
    var setNumber: Int
    var weight: Double
    var reps: Int
    var durationSeconds: Int?
    var completedAt: Date?
    var notes: String?
    /// Raw `SetType`. Nil means a normal set (also what every pre-existing row decodes to).
    var setType: String?
    var exercise: PlannedExercise?

    init(
        setNumber: Int,
        weight: Double = 0,
        reps: Int = 0,
        durationSeconds: Int? = nil,
        completedAt: Date? = nil,
        notes: String? = nil,
        setType: SetType = .normal
    ) {
        self.setNumber = setNumber
        self.weight = weight
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.completedAt = completedAt
        self.notes = notes
        self.setType = setType == .normal ? nil : setType.rawValue
    }

    var kind: SetType {
        get { SetType(rawValue: setType ?? "") ?? .normal }
        set { setType = newValue == .normal ? nil : newValue.rawValue }
    }

    var isCompleted: Bool { completedAt != nil }

    var volume: Double { weight * Double(reps) }

    /// Epley estimate. Nil when the set can't support one (no load or no reps).
    var estimatedOneRepMax: Double? {
        guard weight > 0, reps > 0 else { return nil }
        if reps == 1 { return weight }
        return weight * (1 + Double(reps) / 30)
    }
}
