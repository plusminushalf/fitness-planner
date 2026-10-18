import SwiftUI
import SwiftData

/// Which numeric field in the set table has the keyboard.
enum SetField: Hashable {
    case weight(PersistentIdentifier)
    case reps(PersistentIdentifier)
}

/// Fixed column widths shared by the table header and every row, so columns line up.
enum SetColumns {
    static let set: CGFloat = 36
    static let weight: CGFloat = 70
    static let reps: CGFloat = 58
    static let time: CGFloat = 84
    static let action: CGFloat = 44
    static let spacing: CGFloat = 8
}

struct SetTableHeader: View {
    let timeBased: Bool

    var body: some View {
        HStack(spacing: SetColumns.spacing) {
            ColumnLabel("Set", alignment: .center).frame(width: SetColumns.set)
            ColumnLabel("Previous")
            if timeBased {
                ColumnLabel("Time", alignment: .center).frame(width: SetColumns.time)
                Color.clear.frame(width: SetColumns.action, height: 1)
            } else {
                ColumnLabel("kg", alignment: .center).frame(width: SetColumns.weight)
                ColumnLabel("Reps", alignment: .center).frame(width: SetColumns.reps)
            }
            Image(systemName: "checkmark")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: SetColumns.action)
                .accessibilityLabel("Done")
        }
        .padding(.top, 4)
        .padding(.bottom, 2)
    }
}

/// One row of the Hevy-style set table: SET · PREVIOUS · KG · REPS · ✓.
struct SetRowView: View {
    @Bindable var entry: LoggedSet
    let timeBased: Bool
    let label: String
    let previous: LoggedSet?
    let targetWeight: Double?
    let targetReps: String?
    let isTiming: Bool
    var focus: FocusState<SetField?>.Binding
    let onToggle: () -> Void
    let onSetType: (SetType) -> Void
    let onDelete: () -> Void
    let onTimer: () -> Void
    let onEditDuration: () -> Void

    @State private var weightText = ""
    @State private var repsText = ""

    private var id: PersistentIdentifier { entry.persistentModelID }

    var body: some View {
        HStack(spacing: SetColumns.spacing) {
            typeMenu
            previousButton
            if timeBased {
                timeCell
                timerButton
            } else {
                weightField
                repsField
            }
            checkButton
        }
        .frame(minHeight: 44)
        .onAppear(perform: syncFromModel)
        .onChange(of: entry.weight) { _, new in
            if parse(weightText) != new { weightText = new == 0 ? "" : Fmt.number(new) }
        }
        .onChange(of: entry.reps) { _, new in
            if (Int(repsText) ?? 0) != new { repsText = new == 0 ? "" : String(new) }
        }
    }

    // MARK: Cells

    private var typeMenu: some View {
        Menu {
            Picker("Set type", selection: Binding(get: { entry.kind }, set: { newValue in onSetType(newValue) })) {
                ForEach([SetType.warmup, .normal, .failure, .drop]) { t in
                    Text(t.displayName).tag(t)
                }
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete set", systemImage: "trash")
            }
        } label: {
            Text(label)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(entry.kind == .normal ? Color.primary : entry.kind.tint)
                .frame(width: SetColumns.set, height: 44)
                .contentShape(.rect)
        }
        .accessibilityLabel("Set \(label), \(entry.kind.displayName)")
    }

    private var previousText: String {
        guard let previous else { return "—" }
        return Fmt.set(previous, timeBased: timeBased)
    }

    private var previousButton: some View {
        Button {
            guard let previous, !entry.isCompleted else { return }
            if timeBased {
                entry.durationSeconds = previous.durationSeconds
            } else {
                entry.weight = previous.weight
                entry.reps = previous.reps
            }
        } label: {
            Text(previousText)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(previous == nil ? "No previous set" : "Previous: \(previousText). Tap to copy.")
    }

    private var weightPlaceholder: String {
        if let w = previous?.weight, w > 0 { return Fmt.number(w) }
        if let w = targetWeight { return Fmt.number(w) }
        return "–"
    }

    private var repsPlaceholder: String {
        if let r = previous?.reps, r > 0 { return String(r) }
        return targetReps ?? "–"
    }

    private var weightField: some View {
        TextField("", text: $weightText)
            .keyboardType(.decimalPad)
            .focused(focus, equals: .weight(id))
            .modifier(NumberCell(width: SetColumns.weight, completed: entry.isCompleted, placeholder: weightText.isEmpty ? weightPlaceholder : nil))
            .onChange(of: weightText) { _, new in
                entry.weight = parse(new) ?? 0
            }
            .accessibilityLabel("Weight in kilograms")
    }

    private var repsField: some View {
        TextField("", text: $repsText)
            .keyboardType(.numberPad)
            .focused(focus, equals: .reps(id))
            .modifier(NumberCell(width: SetColumns.reps, completed: entry.isCompleted, placeholder: repsText.isEmpty ? repsPlaceholder : nil))
            .onChange(of: repsText) { _, new in
                entry.reps = Int(new) ?? 0
            }
            .accessibilityLabel("Reps")
    }

    private var timeCell: some View {
        Button(action: onEditDuration) {
            Text(Fmt.clock(entry.durationSeconds ?? 0))
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(.primary)
                .frame(width: SetColumns.time, height: 32)
                .background(entry.isCompleted ? Color.clear : Color.fieldFill, in: .rect(cornerRadius: 6, style: .continuous))
                .frame(height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Time \(formatDuration(entry.durationSeconds ?? 0)). Tap to edit.")
    }

    private var timerButton: some View {
        Button(action: onTimer) {
            Image(systemName: isTiming ? "stop.fill" : "play.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(entry.isCompleted ? Color.secondary : Color.brand)
                .frame(width: SetColumns.action, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(entry.isCompleted)
        .accessibilityLabel(isTiming ? "Stop timer" : "Start timer")
    }

    private var checkButton: some View {
        Button(action: onToggle) {
            Image(systemName: "checkmark")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(entry.isCompleted ? Color.white : Color.secondary)
                .frame(width: 32, height: 32)
                .background(entry.isCompleted ? Color.doneGreen : Color.fieldFill, in: .rect(cornerRadius: 6, style: .continuous))
                .frame(width: SetColumns.action, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: entry.isCompleted)
        .accessibilityLabel(entry.isCompleted ? "Completed. Tap to undo." : "Mark set complete")
    }

    // MARK: Helpers

    private func syncFromModel() {
        weightText = entry.weight == 0 ? "" : Fmt.number(entry.weight)
        repsText = entry.reps == 0 ? "" : String(entry.reps)
    }

    private func parse(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }
}

/// A 32pt pill inside a 44pt hit area. The placeholder is drawn by hand: TextField prompts
/// ignore foreground styling and render too faint to read, and this value is what ✓ logs.
private struct NumberCell: ViewModifier {
    let width: CGFloat
    let completed: Bool
    let placeholder: String?

    func body(content: Content) -> some View {
        content
            .font(.body.weight(.semibold).monospacedDigit())
            .multilineTextAlignment(.center)
            .frame(width: width, height: 44)
            .background(alignment: .center) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(completed ? Color.clear : Color.fieldFill)
                        .frame(height: 32)
                    if let placeholder {
                        Text(placeholder)
                            .font(.body.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Color.primary.opacity(0.6))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .accessibilityHidden(true)
                    }
                }
            }
            .contentShape(.rect)
    }
}
