import SwiftUI

/// Horizontal strip of day pills across the plan's span.
struct DateStrip: View {
    // A single continuous list that stays identical across navigation. Because it never changes
    // when the selection moves, selecting a date in an adjacent month is mechanically the same as
    // selecting one in the current month: pills keep their identity and only the scroll + tint move.
    let dates: [Date]
    @Binding var selectedDate: Date
    let datesWithWorkouts: Set<Date>
    let completedDates: Set<Date>

    private let today: Date = Calendar.current.startOfDay(for: .now)

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                // Lazy so a multi-month range only materialises the visible pills; scrollTo still
                // reaches off-screen ids.
                LazyHStack(spacing: 4) {
                    ForEach(dates, id: \.self) { date in
                        DayPill(
                            date: date,
                            isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                            isToday: Calendar.current.isDate(date, inSameDayAs: today),
                            hasWorkout: datesWithWorkouts.contains(date),
                            isCompleted: completedDates.contains(date)
                        )
                        .id(date)
                        .onTapGesture { selectedDate = Calendar.current.startOfDay(for: date) }
                    }
                }
                .padding(.horizontal, 12)
            }
            // A LazyHStack is greedy in the cross axis; pin the height to the pill.
            .frame(height: 68)
            .sensoryFeedback(.selection, trigger: selectedDate)
            .onAppear {
                // Defer one runloop tick: on first appear the lazy stack hasn't laid out the target
                // cell yet, so an immediate scrollTo would leave today off-screen.
                DispatchQueue.main.async {
                    proxy.scrollTo(targetID, anchor: .center)
                }
            }
            .onChange(of: selectedDate) { _, _ in
                withAnimation(.snappy) { proxy.scrollTo(targetID, anchor: .center) }
            }
        }
    }

    private var targetID: Date {
        let cal = Calendar.current
        return dates.first { cal.isDate($0, inSameDayAs: selectedDate) } ?? dates.first ?? selectedDate
    }
}

private struct DayPill: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasWorkout: Bool
    let isCompleted: Bool

    private static let weekdayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE"
        df.locale = .current
        return df
    }()

    var body: some View {
        VStack(spacing: 3) {
            Text(Self.weekdayFormatter.string(from: date))
                .font(.caption2.weight(.medium))
                .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(numberColor)
            indicator
                .frame(height: 8)
        }
        .frame(width: 46, height: 64)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.brand : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isToday && !isSelected ? Color.brand : Color.clear, lineWidth: 1.5)
        )
        .contentShape(.rect(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var numberColor: Color {
        if isSelected { return .white }
        if isToday { return .brand }
        return .primary
    }

    @ViewBuilder
    private var indicator: some View {
        if isCompleted {
            Image(systemName: "checkmark")
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(isSelected ? Color.white : Color.doneGreen)
        } else if hasWorkout {
            Circle()
                .fill(isSelected ? Color.white : Color.brand)
                .frame(width: 5, height: 5)
        } else {
            Color.clear.frame(width: 5, height: 5)
        }
    }

    private var accessibilityText: String {
        var parts = [date.formatted(.dateTime.weekday(.wide).day().month(.wide))]
        if isToday { parts.append("today") }
        if isCompleted { parts.append("workout done") } else if hasWorkout { parts.append("workout planned") }
        return parts.joined(separator: ", ")
    }
}

/// Toolbar menu that jumps the selection to another month of the same year.
struct MonthYearPicker: View {
    let displayedMonth: Date
    let onSelect: (Date) -> Void

    private static let labelFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMMM"
        df.locale = .current
        return df
    }()

    private var months: [Date] {
        let cal = Calendar.current
        let year = cal.component(.year, from: displayedMonth)
        return (1...12).compactMap { month -> Date? in
            var comps = DateComponents()
            comps.year = year
            comps.month = month
            return cal.date(from: comps)
        }
    }

    var body: some View {
        Menu {
            ForEach(months, id: \.self) { date in
                Button {
                    onSelect(date)
                } label: {
                    if Calendar.current.isDate(date, equalTo: displayedMonth, toGranularity: .month) {
                        Label(format(date), systemImage: "checkmark")
                    } else {
                        Text(format(date))
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(format(displayedMonth))
                    .font(.headline)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
        }
    }

    private func format(_ date: Date) -> String {
        MonthYearPicker.labelFormatter.string(from: date)
    }
}

func clampSameDayOfMonth(from oldDate: Date, into newMonth: Date) -> Date {
    let cal = Calendar.current
    let day = cal.component(.day, from: oldDate)
    var comps = cal.dateComponents([.year, .month], from: newMonth)
    let range = cal.range(of: .day, in: .month, for: newMonth) ?? 1..<2
    comps.day = min(day, range.upperBound - 1)
    return cal.date(from: comps).map { cal.startOfDay(for: $0) } ?? newMonth
}
