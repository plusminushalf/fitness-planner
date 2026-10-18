import Foundation
import SwiftData

// MARK: - Day & exercise helpers

extension WorkoutDay {
    enum Status {
        case planned
        case inProgress
        case completed
    }

    /// Warmup → exercises → cooldown, then file order. Every screen lists exercises in this order.
    var orderedExercises: [PlannedExercise] {
        exercises.sorted { a, b in
            let sa = a.workoutSection.orderIndex
            let sb = b.workoutSection.orderIndex
            if sa != sb { return sa < sb }
            return a.orderIndex < b.orderIndex
        }
    }

    var completedSets: [LoggedSet] {
        exercises.flatMap { $0.sets.filter(\.isCompleted) }
    }

    var completedSetCount: Int { completedSets.count }

    var totalSetCount: Int { exercises.reduce(0) { $0 + $1.sets.count } }

    var volume: Double {
        exercises.reduce(0) { acc, ex in
            ex.isTimeBased ? acc : acc + ex.sets.filter(\.isCompleted).reduce(0) { $0 + $1.volume }
        }
    }

    var hasLoggedWork: Bool { exercises.contains { $0.sets.contains(where: \.isCompleted) } }

    var status: Status {
        if completedAt != nil { return .completed }
        if startedAt != nil || hasLoggedWork { return .inProgress }
        return .planned
    }

    /// Frozen duration for finished workouts, live elapsed time for running ones.
    func elapsedSeconds(now: Date = .now) -> Int? {
        if let durationSeconds { return durationSeconds }
        guard let startedAt else { return nil }
        let end = completedAt ?? now
        return max(0, Int(end.timeIntervalSince(startedAt)))
    }

    var weekdayName: String {
        let df = DateFormatter()
        df.dateFormat = "EEEE"
        df.locale = .current
        return df.string(from: date)
    }

    var displayTitle: String {
        if let title, !title.trimmingCharacters(in: .whitespaces).isEmpty { return title }
        return "\(weekdayName) workout"
    }

    var nextOrderIndex: Int {
        (exercises.map(\.orderIndex).max() ?? -1) + 1
    }
}

extension PlannedExercise {
    var orderedSets: [LoggedSet] { sets.sorted { $0.setNumber < $1.setNumber } }

    var completedSets: [LoggedSet] { orderedSets.filter(\.isCompleted) }

    var muscle: MuscleGroup { ExerciseCatalog.muscle(for: name, stored: muscleGroup) }

    var key: String { ExerciseKey.key(name) }

    /// "3 × 8-10 · 60 kg" or "1m 30s".
    var targetSummary: String {
        ExerciseSpec(exercise: self).summary
    }

    var videoID: String? {
        guard let raw = videoURL?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }
        return YouTubeURL.videoID(from: raw)
    }
}

// MARK: - History & records

/// One exercise as performed on one day: the completed sets only.
struct ExerciseSession: Identifiable {
    let exercise: PlannedExercise
    let day: WorkoutDay
    let sets: [LoggedSet]

    var id: PersistentIdentifier { exercise.persistentModelID }
    var date: Date { day.date }
    var isTimeBased: Bool { exercise.isTimeBased }
    var workingSets: [LoggedSet] { sets.filter { $0.kind.countsTowardRecords } }

    var heaviestWeight: Double? { workingSets.map(\.weight).filter { $0 > 0 }.max() }
    var bestOneRepMax: Double? { workingSets.compactMap(\.estimatedOneRepMax).max() }
    var bestSetVolume: Double? { workingSets.map(\.volume).filter { $0 > 0 }.max() }
    var volume: Double { sets.reduce(0) { $0 + $1.volume } }
    var totalReps: Int { sets.reduce(0) { $0 + $1.reps } }
    var mostReps: Int? { workingSets.map(\.reps).filter { $0 > 0 }.max() }
    var longestDuration: Int? { sets.compactMap(\.durationSeconds).max() }

    /// The set Hevy would call "best": highest estimated 1RM, then heaviest, then most reps.
    var bestSet: LoggedSet? {
        workingSets.max { a, b in
            let ea = a.estimatedOneRepMax ?? 0, eb = b.estimatedOneRepMax ?? 0
            if ea != eb { return ea < eb }
            if a.weight != b.weight { return a.weight < b.weight }
            return a.reps < b.reps
        } ?? sets.last
    }
}

enum RecordKind: String, CaseIterable, Identifiable {
    case heaviestWeight
    case bestOneRepMax
    case bestSetVolume
    case mostReps
    case longestDuration

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .heaviestWeight: return "Heaviest weight"
        case .bestOneRepMax: return "Best est. 1RM"
        case .bestSetVolume: return "Best set volume"
        case .mostReps: return "Most reps"
        case .longestDuration: return "Longest time"
        }
    }

    func format(_ value: Double) -> String {
        switch self {
        case .heaviestWeight, .bestOneRepMax: return Fmt.weight(value)
        case .bestSetVolume: return Fmt.volume(value)
        case .mostReps: return "\(Int(value)) reps"
        case .longestDuration: return formatDuration(Int(value))
        }
    }
}

struct PersonalRecords {
    var values: [RecordKind: Double] = [:]
    var dates: [RecordKind: Date] = [:]

    var isEmpty: Bool { values.isEmpty }

    mutating func absorb(_ session: ExerciseSession) {
        let candidates: [(RecordKind, Double?)] = [
            (.heaviestWeight, session.heaviestWeight),
            (.bestOneRepMax, session.bestOneRepMax),
            (.bestSetVolume, session.bestSetVolume),
            (.mostReps, session.mostReps.map(Double.init)),
            (.longestDuration, session.longestDuration.map(Double.init)),
        ]
        for (kind, value) in candidates {
            guard let value, value > 0 else { continue }
            if value > (values[kind] ?? 0) {
                values[kind] = value
                dates[kind] = session.date
            }
        }
    }

    /// Records a single set beats. A first-ever performance sets a baseline, not a PR.
    func beaten(by set: LoggedSet, timeBased: Bool) -> [RecordKind] {
        guard set.kind.countsTowardRecords, !isEmpty else { return [] }
        var out: [RecordKind] = []
        if timeBased {
            if let d = set.durationSeconds, let best = values[.longestDuration], Double(d) > best {
                out.append(.longestDuration)
            }
            return out
        }
        if set.weight > 0, let best = values[.heaviestWeight], set.weight > best {
            out.append(.heaviestWeight)
        }
        if let e = set.estimatedOneRepMax, let best = values[.bestOneRepMax], e > best + 0.01 {
            out.append(.bestOneRepMax)
        }
        if set.volume > 0, let best = values[.bestSetVolume], set.volume > best {
            out.append(.bestSetVolume)
        }
        return out
    }
}

struct RecordHit: Identifiable {
    let exerciseName: String
    let kind: RecordKind
    let value: Double
    var id: String { exerciseName + kind.rawValue }
}

/// Every performed exercise across every workout, keyed by normalised name, newest first.
/// Cheap enough to rebuild per screen at personal-log scale.
struct ExerciseHistoryIndex {
    private(set) var sessionsByKey: [String: [ExerciseSession]] = [:]

    init(days: [WorkoutDay]) {
        var map: [String: [ExerciseSession]] = [:]
        for day in days {
            for exercise in day.exercises {
                let done = exercise.completedSets
                guard !done.isEmpty else { continue }
                map[exercise.key, default: []].append(ExerciseSession(exercise: exercise, day: day, sets: done))
            }
        }
        for key in map.keys {
            map[key]?.sort { $0.date > $1.date }
        }
        sessionsByKey = map
    }

    init(context: ModelContext) {
        let days = (try? context.fetch(FetchDescriptor<WorkoutDay>())) ?? []
        self.init(days: days)
    }

    func sessions(for name: String) -> [ExerciseSession] {
        sessionsByKey[ExerciseKey.key(name)] ?? []
    }

    /// The most recent earlier performance, i.e. what goes in the PREVIOUS column.
    func previousSession(for name: String, before date: Date) -> ExerciseSession? {
        let cal = Calendar.current
        return sessions(for: name).first { $0.date < date && !cal.isDate($0.date, inSameDayAs: date) }
    }

    /// Records from sessions strictly before `date` (pass nil for all-time).
    func records(for name: String, before date: Date? = nil) -> PersonalRecords {
        var r = PersonalRecords()
        let cal = Calendar.current
        for s in sessions(for: name).reversed() {
            if let date, s.date >= date || cal.isDate(s.date, inSameDayAs: date) { continue }
            r.absorb(s)
        }
        return r
    }

    /// PRs set during `day`, judged against everything logged before it.
    func recordHits(in day: WorkoutDay) -> [RecordHit] {
        var hits: [RecordHit] = []
        for exercise in day.orderedExercises {
            var prior = records(for: exercise.name, before: day.date)
            guard !prior.isEmpty else { continue }
            var best: [RecordKind: Double] = [:]
            for set in exercise.completedSets {
                for kind in prior.beaten(by: set, timeBased: exercise.isTimeBased) {
                    let value: Double
                    switch kind {
                    case .heaviestWeight: value = set.weight
                    case .bestOneRepMax: value = set.estimatedOneRepMax ?? 0
                    case .bestSetVolume: value = set.volume
                    case .mostReps: value = Double(set.reps)
                    case .longestDuration: value = Double(set.durationSeconds ?? 0)
                    }
                    best[kind] = max(best[kind] ?? 0, value)
                    prior.values[kind] = max(prior.values[kind] ?? 0, value)
                }
            }
            for kind in RecordKind.allCases {
                if let v = best[kind] {
                    hits.append(RecordHit(exerciseName: exercise.name, kind: kind, value: v))
                }
            }
        }
        return hits
    }

    var allKeys: [String] { Array(sessionsByKey.keys) }
}

// MARK: - Exercise spec & factory

/// A value-type description of an exercise to add: from the catalog, a routine, a form, or a past day.
struct ExerciseSpec: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var section: WorkoutSection = .exercise
    var targetSets: Int?
    var targetReps: String?
    var targetWeight: Double?
    var durationSeconds: Int?
    var restSeconds: Int?
    var videoURL: String?
    var notes: String?
    var muscleGroup: MuscleGroup?

    var isTimeBased: Bool { durationSeconds != nil }

    init(
        name: String,
        section: WorkoutSection = .exercise,
        targetSets: Int? = nil,
        targetReps: String? = nil,
        targetWeight: Double? = nil,
        durationSeconds: Int? = nil,
        restSeconds: Int? = nil,
        videoURL: String? = nil,
        notes: String? = nil,
        muscleGroup: MuscleGroup? = nil
    ) {
        self.name = name
        self.section = section
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.durationSeconds = durationSeconds
        self.restSeconds = restSeconds
        self.videoURL = videoURL
        self.notes = notes
        self.muscleGroup = muscleGroup
    }

    init(catalog entry: CatalogExercise) {
        self.init(
            name: entry.name,
            section: entry.muscle == .mobility ? .warmup : .exercise,
            durationSeconds: entry.defaultDuration,
            muscleGroup: entry.muscle
        )
    }

    init(exercise e: PlannedExercise) {
        self.init(
            name: e.name,
            section: e.workoutSection,
            targetSets: e.targetSets,
            targetReps: e.targetReps,
            targetWeight: e.targetWeight,
            durationSeconds: e.durationSeconds,
            restSeconds: e.restSeconds,
            videoURL: e.videoURL,
            notes: e.notes,
            muscleGroup: e.muscleGroup.flatMap(MuscleGroup.init(rawValue:))
        )
    }

    init(routineExercise e: RoutineExercise) {
        self.init(
            name: e.name,
            section: e.workoutSection,
            targetSets: e.targetSets,
            targetReps: e.targetReps,
            targetWeight: e.targetWeight,
            durationSeconds: e.durationSeconds,
            restSeconds: e.restSeconds,
            videoURL: e.videoURL,
            notes: e.notes,
            muscleGroup: e.muscleGroup.flatMap(MuscleGroup.init(rawValue:))
        )
    }

    /// Turns what was actually done into the next session's targets.
    init(performed e: PlannedExercise) {
        self.init(exercise: e)
        let done = e.completedSets.filter { $0.kind.countsTowardRecords }
        guard !e.isTimeBased, !done.isEmpty else { return }
        targetSets = done.count
        if targetReps == nil, let reps = done.map(\.reps).max(), reps > 0 { targetReps = String(reps) }
        if let top = done.map(\.weight).max(), top > 0 { targetWeight = top }
    }

    var summary: String {
        if let secs = durationSeconds { return formatDuration(secs) }
        var parts: [String] = []
        let sets = targetSets.map(String.init)
        switch (sets, targetReps) {
        case let (s?, r?): parts.append("\(s) × \(r)")
        case let (s?, nil): parts.append("\(s) \(s == "1" ? "set" : "sets")")
        case let (nil, r?): parts.append("\(r) reps")
        default: break
        }
        if let w = targetWeight { parts.append(Fmt.weight(w)) }
        return parts.joined(separator: " · ")
    }
}

enum WorkoutFactory {
    /// The day for `date`, creating a manual one when nothing is scheduled.
    static func day(
        for date: Date,
        existing: WorkoutDay?,
        plan: WorkoutPlan?,
        title: String? = nil,
        context: ModelContext
    ) -> WorkoutDay {
        if let existing { return existing }
        let day = WorkoutDay(date: Calendar.current.startOfDay(for: date))
        day.isManual = true
        day.title = title
        day.plan = plan
        context.insert(day)
        return day
    }

    /// Appends exercises with seeded sets. Rep-based exercises get as many empty sets as the
    /// target says, falling back to last session's count, then 3.
    @discardableResult
    static func append(
        _ specs: [ExerciseSpec],
        to day: WorkoutDay,
        history: ExerciseHistoryIndex?,
        context: ModelContext
    ) -> [PlannedExercise] {
        var order = day.nextOrderIndex
        var created: [PlannedExercise] = []
        for spec in specs {
            let exercise = PlannedExercise(
                name: spec.name,
                orderIndex: order,
                section: spec.section,
                targetSets: spec.targetSets,
                targetReps: spec.targetReps,
                targetWeight: spec.targetWeight,
                durationSeconds: spec.durationSeconds,
                restSeconds: spec.restSeconds,
                videoURL: spec.videoURL,
                notes: spec.notes,
                muscleGroup: spec.muscleGroup?.rawValue
            )
            order += 1
            exercise.day = day
            context.insert(exercise)

            if let secs = spec.durationSeconds {
                let set = LoggedSet(setNumber: 1, durationSeconds: secs)
                set.exercise = exercise
                context.insert(set)
            } else {
                let previousCount = history?.previousSession(for: spec.name, before: day.date)?.sets.count
                let count = max(1, spec.targetSets ?? previousCount ?? 3)
                for n in 1...count {
                    let set = LoggedSet(setNumber: n)
                    set.exercise = exercise
                    context.insert(set)
                }
            }
            created.append(exercise)
        }
        return created
    }

    static func replaceExercises(of routine: Routine, with specs: [ExerciseSpec], context: ModelContext) {
        for e in routine.exercises { context.delete(e) }
        routine.exercises = []
        for (i, spec) in specs.enumerated() {
            let e = RoutineExercise(spec: spec, orderIndex: i)
            e.routine = routine
            context.insert(e)
        }
        routine.updatedAt = .now
    }

    @discardableResult
    static func makeRoutine(from day: WorkoutDay, name: String, context: ModelContext) -> Routine {
        let routine = Routine(name: name)
        context.insert(routine)
        let specs = day.orderedExercises.map { $0.hasLoggedSets ? ExerciseSpec(performed: $0) : ExerciseSpec(exercise: $0) }
        replaceExercises(of: routine, with: specs, context: context)
        return routine
    }

    /// Adds a fresh set after the last one, copying its type unless it was a warm-up.
    @discardableResult
    static func addSet(to exercise: PlannedExercise, context: ModelContext) -> LoggedSet {
        let last = exercise.orderedSets.last
        let set = LoggedSet(
            setNumber: (last?.setNumber ?? 0) + 1,
            durationSeconds: exercise.isTimeBased ? (last?.durationSeconds ?? exercise.durationSeconds) : nil,
            setType: last?.kind == .warmup ? .normal : (last?.kind ?? .normal)
        )
        set.exercise = exercise
        context.insert(set)
        return set
    }

    /// Deletes a set and renumbers the rest so set numbers stay contiguous.
    static func delete(_ set: LoggedSet, context: ModelContext) {
        guard let exercise = set.exercise else {
            context.delete(set)
            return
        }
        exercise.sets.removeAll { $0.persistentModelID == set.persistentModelID }
        context.delete(set)
        for (i, s) in exercise.orderedSets.enumerated() {
            s.setNumber = i + 1
        }
    }
}

extension PlannedExercise {
    fileprivate var hasLoggedSets: Bool { sets.contains(where: \.isCompleted) }
}
