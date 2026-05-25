import Foundation
import SwiftData

@Model
final class WorkoutPlan {
    var name: String
    var importedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \WorkoutDay.plan)
    var days: [WorkoutDay] = []

    init(name: String, importedAt: Date = .now) {
        self.name = name
        self.importedAt = importedAt
    }
}
