import SwiftUI
import SwiftData

/// Multi-select exercise picker, presented as a sheet. Returns specs in the order they were picked.
struct ExercisePickerView: View {
    var title: String = "Add Exercises"
    let onAdd: ([ExerciseSpec]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query private var days: [WorkoutDay]

    @State private var search = ""
    @State private var muscle: MuscleGroup?
    @State private var selectedKeys: [String] = []
    @State private var showingCreate = false
    @State private var createdSpec: ExerciseSpec?

    private var library: [ExerciseLibraryEntry] {
        ExerciseLibraryEntry.library(from: ExerciseHistoryIndex(days: days))
    }

    var body: some View {
        let library = self.library
        let filtered = library.filter { (muscle == nil || $0.muscle == muscle) && $0.matches(search) }
        let recent = filtered
            .filter(\.isPerformed)
            .sorted { ($0.latest?.date ?? .distantPast) > ($1.latest?.date ?? .distantPast) }
            .prefix(8)
        let available = MuscleGroup.allCases.filter { g in library.contains { $0.muscle == g } }
        let trimmedSearch = search.trimmingCharacters(in: .whitespaces)

        NavigationStack {
            List {
                Section {
                    MuscleFilterBar(selection: $muscle, available: available)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowSeparator(.hidden)
                }

                if filtered.isEmpty, !trimmedSearch.isEmpty {
                    Section {
                        Button {
                            showingCreate = true
                        } label: {
                            Label("Create “\(trimmedSearch)”", systemImage: "plus.circle.fill")
                                .font(.body.weight(.semibold))
                                .frame(minHeight: 44)
                        }
                    }
                }

                if !recent.isEmpty {
                    Section {
                        ForEach(Array(recent)) { row($0) }
                    } header: {
                        ColumnLabel("Recent")
                    }
                }

                if !filtered.isEmpty {
                    Section {
                        ForEach(filtered) { row($0) }
                    } header: {
                        ColumnLabel("All exercises")
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search exercises")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Create") { showingCreate = true }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    let byKey = Dictionary(library.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
                    onAdd(selectedKeys.compactMap { byKey[$0]?.spec })
                    dismiss()
                } label: {
                    Text(addLabel)
                }
                .buttonStyle(.primary)
                .disabled(selectedKeys.isEmpty)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.bar)
            }
            .sheet(isPresented: $showingCreate, onDismiss: {
                // Hand the new exercise back only after the form is gone, then close the picker.
                if let spec = createdSpec {
                    createdSpec = nil
                    onAdd([spec])
                    dismiss()
                }
            }) {
                AddExerciseView(
                    initial: trimmedSearch.isEmpty ? nil : ExerciseSpec(name: trimmedSearch),
                    title: "New Exercise"
                ) { spec in
                    createdSpec = spec
                }
            }
        }
    }

    private var addLabel: String {
        switch selectedKeys.count {
        case 0: return "Select exercises"
        case 1: return "Add 1 exercise"
        default: return "Add \(selectedKeys.count) exercises"
        }
    }

    private func row(_ entry: ExerciseLibraryEntry) -> some View {
        let isSelected = selectedKeys.contains(entry.key)
        return HStack(spacing: 12) {
            ExerciseAvatar(name: entry.name, videoID: entry.videoID, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                Text(entry.muscle.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? Color.brand : Color(.tertiaryLabel))
        }
        .padding(.vertical, 2)
        .frame(minHeight: 44)
        .contentShape(.rect)
        .onTapGesture { toggle(entry.key) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func toggle(_ key: String) {
        if let i = selectedKeys.firstIndex(of: key) {
            selectedKeys.remove(at: i)
        } else {
            selectedKeys.append(key)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
