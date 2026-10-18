import SwiftUI

// MARK: - Colour roles
//
// One tint (AccentColor, Hevy blue) drives everything interactive. The only other hues are
// reserved for set state: green for done, and the set-type letters.

extension Color {
    /// Hevy blue, from the AccentColor asset (light #1F6FEB, dark #3D8BFF).
    static let brand = Color("AccentColor")
    static let doneGreen = Color.green
    static let doneRowFill = Color.green.opacity(0.16)
    static let fieldFill = Color(.tertiarySystemFill)
    static let cardFill = Color(.secondarySystemGroupedBackground)
    static let screenFill = Color(.systemGroupedBackground)
    static let recordGold = Color.orange
}

extension SetType {
    var tint: Color {
        switch self {
        case .normal: return .primary
        case .warmup: return .orange
        case .drop: return .purple
        case .failure: return .red
        }
    }
}

// MARK: - Buttons

/// Full-width filled tint button: the one primary action on a screen.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 16)
            .background(
                Color.brand.opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4),
                in: .rect(cornerRadius: 10, style: .continuous)
            )
            .contentShape(.rect(cornerRadius: 10, style: .continuous))
    }
}

/// Full-width grey fill button for secondary actions (Add Set, New Routine).
struct SecondaryButtonStyle: ButtonStyle {
    var foreground: Color = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 12)
            .background(
                Color.fieldFill.opacity(configuration.isPressed ? 0.6 : 1),
                in: .rect(cornerRadius: 10, style: .continuous)
            )
            .contentShape(.rect(cornerRadius: 10, style: .continuous))
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
    static func secondary(_ foreground: Color) -> SecondaryButtonStyle { SecondaryButtonStyle(foreground: foreground) }
}

// MARK: - Surfaces

extension View {
    /// A grouped-background card. Never nest these.
    func card(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardFill, in: .rect(cornerRadius: 12, style: .continuous))
    }
}

/// Small grey label over a value, the Hevy stats line ("Duration / 52min").
struct StatPair: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Uppercase caption used for table headers and list section labels.
struct ColumnLabel: View {
    let text: String
    var alignment: Alignment = .leading

    init(_ text: String, alignment: Alignment = .leading) {
        self.text = text
        self.alignment = alignment
    }

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: alignment)
    }
}

/// Round exercise badge: the plan's YouTube thumbnail when there is one, initials otherwise.
/// The app ships no exercise imagery, so this never pretends to show the movement.
struct ExerciseAvatar: View {
    let name: String
    var videoID: String?
    var size: CGFloat = 40

    private var initials: String {
        let words = name.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        return words.prefix(2).compactMap(\.first).map { String($0).uppercased() }.joined()
    }

    var body: some View {
        ZStack {
            Circle().fill(Color.fieldFill)
            if let videoID, let url = URL(string: "https://img.youtube.com/vi/\(videoID)/mqdefault.jpg") {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    initialsText
                }
            } else {
                initialsText
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var initialsText: some View {
        Text(initials)
            .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
            .foregroundStyle(.secondary)
    }
}

// MARK: - Toast

private struct ToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let message {
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: message) {
                        try? await Task.sleep(for: .seconds(2.2))
                        withAnimation(.easeOut(duration: 0.25)) { self.message = nil }
                    }
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(.spring(duration: 0.3), value: message)
    }
}

extension View {
    func toast(_ message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}

// MARK: - Formatting

enum Fmt {
    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    static func weight(_ value: Double) -> String {
        "\(number(value)) kg"
    }

    static func volume(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0)))) kg"
    }

    /// Stopwatch style: 0:45, 2:00, 1:05:03.
    static func clock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    /// Compact elapsed time: 52min, 1h 5min, 45s.
    static func elapsed(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let h = seconds / 3600, m = (seconds % 3600) / 60
        if h > 0 { return m == 0 ? "\(h)h" : "\(h)h \(m)min" }
        return "\(m)min"
    }

    /// One set as shown in PREVIOUS and history: "80 kg × 8", "× 12" (bodyweight), "1:30".
    static func set(_ set: LoggedSet, timeBased: Bool) -> String {
        if timeBased { return clock(set.durationSeconds ?? 0) }
        if set.weight > 0 { return "\(number(set.weight)) kg × \(set.reps)" }
        return "\(set.reps) reps"
    }

    static func relative(_ date: Date, now: Date = .now) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: cal.startOfDay(for: date), relativeTo: cal.startOfDay(for: now))
    }

    static func dayAndDate(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }
}

/// "45s", "2m", "1m 30s". Kept global: forms and the duration editor use it directly.
func formatDuration(_ seconds: Int) -> String {
    if seconds < 60 { return "\(seconds)s" }
    let m = seconds / 60
    let s = seconds % 60
    return s == 0 ? "\(m)m" : "\(m)m \(s)s"
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }

    func startOfWeek(for date: Date) -> Date {
        dateInterval(of: .weekOfYear, for: date)?.start ?? startOfDay(for: date)
    }
}
