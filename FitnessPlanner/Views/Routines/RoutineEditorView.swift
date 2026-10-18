import SwiftUI
import SwiftData

/// Create or edit a routine. Works on value-type specs and writes once on Save,
/// so Cancel never leaves a half-edited routine behind.
struct RoutineEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let routine: Routine?

    @State private var name: String
    @State private var specs: [ExerciseSpec]
    @State private var showingPicker = false
    @State private var editing: ExerciseSpec?

    init(routine: Routine?) {
        self.routine = routine
        _name = State(initialValue: routine?.name ?? "")
        _specs = State(initialValue: routine?.orderedExercises.map(ExerciseSpec.init(routineExercise:)) ?? [])
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Routine name", text: $name)
                        .font(.title3.weight(.semibold))
                        .textInputAutocapitalization(.words)
                }

                Section {
                    ForEach(specs) { spec in
                        Button {
                            editing = spec
                        } label: {
                            HStack(spacing: 12) {
                                ExerciseAvatar(
                                    name: spec.name,
                                    videoID: spec.videoURL.flatMap(YouTubeURL.videoID(from:)),
                                    size: 36
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(spec.name)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(Color.brand)
                                    Text(detail(for: spec))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                    .onMove { specs.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { specs.remove(atOffsets: $0) }

                    Button {
                        showingPicker = true
                    } label: {
                        Label("Add Exercises", systemImage: "plus")
                            .font(.body.weight(.semibold))
                    }
                } header: {
                    Text("Exercises")
                } footer: {
                    if !specs.isEmpty {
                        Text("Tap an exercise to set its sets, reps and rest. Drag to reorder.")
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle(routine == nil ? "New Routine" : "Edit Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(trimmedName.isEmpty || specs.isEmpty)
                }
            }
            .sheet(isPresented: $showingPicker) {
                ExercisePickerView(title: "Add to Routine") { added in
                    specs.append(contentsOf: added.map(withDefaultTargets))
                }
            }
            .sheet(item: $editing) { spec in
                AddExerciseView(initial: spec, title: "Edit Exercise") { updated in
                    if let i = specs.firstIndex(where: { $0.id == spec.id }) {
                        specs[i] = updated
                    }
                }
            }
        }
    }

    private func detail(for spec: ExerciseSpec) -> String {
        var parts = [spec.summary]
        if let rest = spec.restSeconds { parts.append("rest \(formatDuration(rest))") }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// Picked exercises arrive without targets; give rep work a sensible 3 sets to edit from.
    private func withDefaultTargets(_ spec: ExerciseSpec) -> ExerciseSpec {
        var s = spec
        if !s.isTimeBased, s.targetSets == nil { s.targetSets = 3 }
        return s
    }

    private func save() {
        let target: Routine
        if let routine {
            target = routine
        } else {
            target = Routine(name: trimmedName)
            context.insert(target)
        }
        target.name = trimmedName
        WorkoutFactory.replaceExercises(of: target, with: specs, context: context)
        dismiss()
    }
}
