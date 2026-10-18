import SwiftUI

/// Create or edit an exercise outside the CSV plan: custom exercises in a workout, and the
/// targets of a routine exercise. Returns an `ExerciseSpec`; callers decide where it goes.
struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let onSave: (ExerciseSpec) -> Void
    private let initial: ExerciseSpec?

    private enum ExerciseKind: String, CaseIterable, Identifiable {
        case reps = "Reps-based"
        case time = "Time-based"
        var id: String { rawValue }
    }

    @State private var name: String
    @State private var section: WorkoutSection
    @State private var kind: ExerciseKind
    @State private var muscle: MuscleGroup?

    // Rep-based fields
    @State private var sets: Int
    @State private var targetReps: String
    @State private var weightText: String

    // Time-based fields
    @State private var durationSeconds: Int
    @State private var showingDurationEditor = false

    // Optional fields
    @State private var restText: String
    @State private var notes: String

    init(initial: ExerciseSpec? = nil, title: String = "New Exercise", onSave: @escaping (ExerciseSpec) -> Void) {
        self.initial = initial
        self.title = title
        self.onSave = onSave
        let spec = initial ?? ExerciseSpec(name: "")
        _name = State(initialValue: spec.name)
        _section = State(initialValue: spec.section)
        _kind = State(initialValue: spec.isTimeBased ? .time : .reps)
        _muscle = State(initialValue: spec.muscleGroup)
        _sets = State(initialValue: spec.targetSets ?? 3)
        _targetReps = State(initialValue: spec.targetReps ?? "")
        _weightText = State(initialValue: spec.targetWeight.map(Fmt.number) ?? "")
        _durationSeconds = State(initialValue: spec.durationSeconds ?? 60)
        _restText = State(initialValue: spec.restSeconds.map(String.init) ?? "")
        _notes = State(initialValue: spec.notes ?? "")
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        guard !trimmedName.isEmpty else { return false }
        switch kind {
        case .reps: return sets >= 1
        case .time: return durationSeconds > 0
        }
    }

    private var inferredMuscle: MuscleGroup {
        ExerciseCatalog.muscle(for: trimmedName, stored: nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Exercise name", text: $name)
                        .textInputAutocapitalization(.words)
                    Picker("Muscle group", selection: $muscle) {
                        Text(trimmedName.isEmpty ? "Automatic" : "Automatic (\(inferredMuscle.displayName))")
                            .tag(MuscleGroup?.none)
                        ForEach(MuscleGroup.allCases) { group in
                            Text(group.displayName).tag(MuscleGroup?.some(group))
                        }
                    }
                    Picker("Section", selection: $section) {
                        ForEach(WorkoutSection.allCases) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                    Picker("Type", selection: $kind) {
                        ForEach(ExerciseKind.allCases) { k in
                            Text(k.rawValue).tag(k)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                switch kind {
                case .reps:
                    Section("Target") {
                        Stepper("Sets: \(sets)", value: $sets, in: 1...20)
                        TextField("Reps (e.g. 5-8, 10, AMRAP), optional", text: $targetReps)
                        TextField("Weight (kg), optional", text: $weightText)
                            .keyboardType(.decimalPad)
                    }
                case .time:
                    Section("Target") {
                        Button {
                            showingDurationEditor = true
                        } label: {
                            HStack {
                                Text("Duration")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(formatDuration(durationSeconds))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Optional") {
                    TextField("Rest between sets (seconds)", text: $restText)
                        .keyboardType(.numberPad)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(initial == nil || initial?.name.isEmpty == true ? "Add" : "Save") { save() }
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingDurationEditor) {
                DurationEditorView(seconds: durationSeconds) { durationSeconds = $0 }
            }
        }
    }

    private func save() {
        guard canSave else { return }
        let rest = Int(restText.trimmingCharacters(in: .whitespaces)).flatMap { $0 > 0 ? $0 : nil }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let reps = targetReps.trimmingCharacters(in: .whitespaces)

        var spec = initial ?? ExerciseSpec(name: trimmedName)
        spec.name = trimmedName
        spec.section = section
        spec.muscleGroup = muscle
        spec.restSeconds = rest
        spec.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        switch kind {
        case .reps:
            spec.targetSets = sets
            spec.targetReps = reps.isEmpty ? nil : reps
            spec.targetWeight = Double(weightText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
            spec.durationSeconds = nil
        case .time:
            spec.targetSets = nil
            spec.targetReps = nil
            spec.targetWeight = nil
            spec.durationSeconds = durationSeconds
        }
        onSave(spec)
        dismiss()
    }
}
