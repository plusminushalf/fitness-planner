import Foundation

enum MuscleGroup: String, CaseIterable, Identifiable {
    case chest
    case back
    case shoulders
    case biceps
    case triceps
    case forearms
    case abs
    case quads
    case hamstrings
    case glutes
    case calves
    case fullBody
    case cardio
    case mobility
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .shoulders: return "Shoulders"
        case .biceps: return "Biceps"
        case .triceps: return "Triceps"
        case .forearms: return "Forearms"
        case .abs: return "Core"
        case .quads: return "Quads"
        case .hamstrings: return "Hamstrings"
        case .glutes: return "Glutes"
        case .calves: return "Calves"
        case .fullBody: return "Full body"
        case .cardio: return "Cardio"
        case .mobility: return "Mobility"
        case .other: return "Other"
        }
    }

    /// Best guess from a free-text exercise name, for CSV rows that don't say.
    /// Order matters: more specific phrases are checked before the words they contain.
    /// Needles match at the start of a word, so "run" doesn't fire on "crunch".
    static func infer(from name: String) -> MuscleGroup {
        let n = " " + ExerciseKey.key(name).lowercased() + " "
        let rules: [(MuscleGroup, [String])] = [
            (.mobility, ["stretch", "pose", "circles", "swings", "cat cow", "mobility", "foam roll", "pull apart", "dislocate", "squat hold", "dead hang"]),
            (.cardio, ["run", "jog", "bike", "cycle", "rower", "erg", "jump rope", "jumping jack", "burpee", "sprint", "walk", "stair", "elliptical"]),
            (.hamstrings, ["leg curl", "hamstring", "romanian", "rdl", "good morning", "nordic", "stiff leg"]),
            (.glutes, ["hip thrust", "glute", "bridge", "abduct"]),
            (.calves, ["calf", "calves"]),
            (.quads, ["squat", "leg press", "lunge", "split squat", "leg extension", "step up", "hack", "wall sit"]),
            (.back, ["deadlift", "row", "pull up", "pullup", "chin up", "chinup", "pulldown", "pull down", "lat ", "shrug", "back extension", "hyperextension"]),
            (.triceps, ["tricep", "pushdown", "push down", "skull", "close grip", "dip", "overhead extension", "kickback"]),
            (.biceps, ["curl", "bicep"]),
            (.forearms, ["wrist", "farmer", "grip", "forearm"]),
            (.shoulders, ["overhead press", "shoulder", "lateral raise", "front raise", "rear delt", "face pull", "military", "arnold", "upright row", "ohp", "y raise"]),
            (.chest, ["bench", "chest", "fly", "flye", "push up", "pushup", "pec", "crossover"]),
            (.abs, ["plank", "crunch", "sit up", "situp", "ab ", "abs", "dead bug", "hollow", "leg raise", "russian twist", "pallof", "woodchop", "core", "l sit"]),
            (.fullBody, ["clean", "snatch", "thruster", "kettlebell swing", "turkish", "complex"]),
        ]
        for (group, needles) in rules where needles.contains(where: { n.contains(" " + $0) }) {
            return group
        }
        return .other
    }
}

/// Normalises exercise names so "Pull-up", "pull up" and "Pull Up " are the same exercise.
enum ExerciseKey {
    static func key(_ name: String) -> String {
        let folded = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let spaced = folded.map { ch -> Character in
            ch.isLetter || ch.isNumber ? ch : " "
        }
        return String(spaced)
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }
}

struct CatalogExercise: Identifiable, Hashable {
    let name: String
    let muscle: MuscleGroup
    /// Seconds for timed movements; nil for sets × reps.
    let defaultDuration: Int?

    var id: String { ExerciseKey.key(name) }

    init(_ name: String, _ muscle: MuscleGroup, seconds: Int? = nil) {
        self.name = name
        self.muscle = muscle
        self.defaultDuration = seconds
    }
}

/// Built-in exercise library. Names only: the app ships no exercise imagery.
enum ExerciseCatalog {
    static let all: [CatalogExercise] = [
        // Chest
        .init("Bench Press", .chest),
        .init("Incline Bench Press", .chest),
        .init("Dumbbell Bench Press", .chest),
        .init("Incline Dumbbell Press", .chest),
        .init("Chest Fly", .chest),
        .init("Cable Crossover", .chest),
        .init("Push-up", .chest),
        .init("Chest Dip", .chest),
        // Back
        .init("Conventional Deadlift", .back),
        .init("Pull-up", .back),
        .init("Chin-up", .back),
        .init("Lat Pulldown", .back),
        .init("Barbell Row", .back),
        .init("Dumbbell Row", .back),
        .init("Seated Cable Row", .back),
        .init("T-Bar Row", .back),
        .init("Shrug", .back),
        .init("Back Extension", .back),
        // Shoulders
        .init("Overhead Press", .shoulders),
        .init("Dumbbell Shoulder Press", .shoulders),
        .init("Arnold Press", .shoulders),
        .init("Lateral Raise", .shoulders),
        .init("Front Raise", .shoulders),
        .init("Rear Delt Fly", .shoulders),
        .init("Face Pull", .shoulders),
        .init("Upright Row", .shoulders),
        // Arms
        .init("Barbell Curl", .biceps),
        .init("Dumbbell Curl", .biceps),
        .init("Hammer Curl", .biceps),
        .init("Preacher Curl", .biceps),
        .init("Cable Curl", .biceps),
        .init("Triceps Pushdown", .triceps),
        .init("Skull Crusher", .triceps),
        .init("Overhead Triceps Extension", .triceps),
        .init("Close-Grip Bench Press", .triceps),
        .init("Triceps Dip", .triceps),
        .init("Wrist Curl", .forearms),
        .init("Farmer's Carry", .forearms),
        // Legs
        .init("Back Squat", .quads),
        .init("Front Squat", .quads),
        .init("Goblet Squat", .quads),
        .init("Leg Press", .quads),
        .init("Hack Squat", .quads),
        .init("Bulgarian Split Squat", .quads),
        .init("Walking Lunges", .quads),
        .init("Leg Extension", .quads),
        .init("Step-up", .quads),
        .init("Romanian Deadlift", .hamstrings),
        .init("Lying Leg Curl", .hamstrings),
        .init("Seated Leg Curl", .hamstrings),
        .init("Good Morning", .hamstrings),
        .init("Nordic Curl", .hamstrings),
        .init("Hip Thrust", .glutes),
        .init("Glute Bridge", .glutes),
        .init("Cable Kickback", .glutes),
        .init("Hip Abduction", .glutes),
        .init("Standing Calf Raise", .calves),
        .init("Seated Calf Raise", .calves),
        // Core
        .init("Plank", .abs, seconds: 60),
        .init("Side Plank", .abs, seconds: 45),
        .init("Hollow Hold", .abs, seconds: 30),
        .init("Hanging Leg Raise", .abs),
        .init("Cable Crunch", .abs),
        .init("Ab Wheel Rollout", .abs),
        .init("Dead Bug", .abs),
        .init("Pallof Press", .abs),
        .init("Russian Twist", .abs),
        // Full body & cardio
        .init("Power Clean", .fullBody),
        .init("Kettlebell Swing", .fullBody),
        .init("Thruster", .fullBody),
        .init("Burpee", .cardio),
        .init("Treadmill Run", .cardio, seconds: 600),
        .init("Stationary Bike", .cardio, seconds: 600),
        .init("Rowing Machine", .cardio, seconds: 600),
        .init("Jump Rope", .cardio, seconds: 120),
        // Mobility
        .init("Arm Circles", .mobility, seconds: 45),
        .init("Hip Circles", .mobility, seconds: 45),
        .init("Cat-Cow", .mobility, seconds: 60),
        .init("Band Pull-Apart", .mobility, seconds: 45),
        .init("Dead Hang", .mobility, seconds: 45),
        .init("Deep Squat Hold", .mobility, seconds: 90),
        .init("Pigeon Stretch", .mobility, seconds: 90),
        .init("Couch Stretch", .mobility, seconds: 90),
        .init("Child's Pose", .mobility, seconds: 60),
        .init("Standing Hamstring Stretch", .mobility, seconds: 60),
        .init("Lat Stretch", .mobility, seconds: 60),
    ]

    private static let byKey: [String: CatalogExercise] = Dictionary(
        all.map { ($0.id, $0) },
        uniquingKeysWith: { first, _ in first }
    )

    static func entry(named name: String) -> CatalogExercise? {
        byKey[ExerciseKey.key(name)]
    }

    /// Stored choice, then the catalog, then a guess from the name.
    static func muscle(for name: String, stored: String?) -> MuscleGroup {
        if let stored, let group = MuscleGroup(rawValue: stored) { return group }
        if let entry = entry(named: name) { return entry.muscle }
        return MuscleGroup.infer(from: name)
    }
}
