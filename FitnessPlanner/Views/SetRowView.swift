import SwiftUI
import SwiftData

enum SetInputStage {
    case weight
    case reps
}

struct CompletedSetSummaryRow: View {
    let set: LoggedSet

    var body: some View {
        HStack {
            Text("Set \(set.setNumber)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(set.weight.formatted(.number.precision(.fractionLength(0...2)))) kg × \(set.reps)")
                .font(.body.monospacedDigit())
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 8))
    }
}

struct ActiveSetInputView: View {
    @Bindable var set: LoggedSet
    let stage: SetInputStage
    let onBack: () -> Void

    @FocusState private var focusedField: SetInputStage?
    @State private var weightText: String = ""
    @State private var repsText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                if stage == .reps {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to weight")
                }
                Text("Set \(set.setNumber)")
                    .font(.title2.bold())
                Spacer()
                Text(stage == .weight ? "Weight (kg)" : "Reps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            inputField
        }
        .padding(.vertical, 8)
        .onAppear {
            syncFromSet()
            focusCurrent()
        }
        .onChange(of: stage) { _, _ in focusCurrent() }
        .onChange(of: set.persistentModelID) { _, _ in
            syncFromSet()
            focusCurrent()
        }
    }

    private func syncFromSet() {
        weightText = set.weight == 0
            ? ""
            : set.weight.formatted(.number.precision(.fractionLength(0...2)))
        repsText = set.reps == 0 ? "" : String(set.reps)
    }

    private func focusCurrent() {
        let target = stage
        DispatchQueue.main.async {
            focusedField = target
        }
    }

    @ViewBuilder
    private var inputField: some View {
        switch stage {
        case .weight:
            TextField("", text: $weightText, prompt: Text("0"))
                .keyboardType(.decimalPad)
                .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                .multilineTextAlignment(.center)
                .focused($focusedField, equals: .weight)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
                .onChange(of: weightText) { _, new in
                    set.weight = Double(new) ?? 0
                }
        case .reps:
            TextField("", text: $repsText, prompt: Text("0"))
                .keyboardType(.numberPad)
                .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                .multilineTextAlignment(.center)
                .focused($focusedField, equals: .reps)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
                .onChange(of: repsText) { _, new in
                    set.reps = Int(new) ?? 0
                }
        }
    }
}
