import SwiftUI

/// A reusable sheet for picking a duration as minutes + seconds. Used for setting a
/// time-based exercise's target, editing it before a run, and editing a recorded session.
struct DurationEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let onSave: (Int) -> Void

    @State private var minutes: Int
    @State private var seconds: Int

    init(seconds total: Int, title: String = "Duration", onSave: @escaping (Int) -> Void) {
        self.title = title
        self.onSave = onSave
        let clamped = max(0, total)
        self._minutes = State(initialValue: clamped / 60)
        self._seconds = State(initialValue: clamped % 60)
    }

    private var totalSeconds: Int { minutes * 60 + seconds }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(totalSeconds == 0 ? "—" : formatDuration(totalSeconds))
                    .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.primary)
                    .padding(.top, 8)

                HStack(spacing: 0) {
                    Picker("Minutes", selection: $minutes) {
                        ForEach(0...59, id: \.self) { Text("\($0) min").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)

                    Picker("Seconds", selection: $seconds) {
                        ForEach(0...59, id: \.self) { Text("\($0) sec").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                }

                Spacer()
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(totalSeconds)
                        dismiss()
                    }
                    .disabled(totalSeconds == 0)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
