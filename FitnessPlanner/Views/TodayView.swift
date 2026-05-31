import SwiftUI
import SwiftData

struct TodayView: View {
    let plan: WorkoutPlan

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var displayedMonth: Date = Calendar.current.startOfMonth(for: .now)

    private var selectedDay: WorkoutDay? {
        let cal = Calendar.current
        return plan.days.first { cal.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var datesWithWorkouts: Set<Date> {
        let cal = Calendar.current
        return Set(plan.days.map { cal.startOfDay(for: $0.date) })
    }

    private var completedDates: Set<Date> {
        let cal = Calendar.current
        return Set(plan.days.filter { $0.completedAt != nil }.map { cal.startOfDay(for: $0.date) })
    }

    var body: some View {
        VStack(spacing: 0) {
            DateStrip(
                month: displayedMonth,
                selectedDate: $selectedDate,
                datesWithWorkouts: datesWithWorkouts,
                completedDates: completedDates
            )
            Divider()
            content
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                MonthYearPicker(displayedMonth: $displayedMonth)
            }
        }
        .onChange(of: displayedMonth) { _, newMonth in
            selectedDate = clampSameDayOfMonth(from: selectedDate, into: newMonth)
        }
        .onChange(of: selectedDate) { _, newDate in
            let cal = Calendar.current
            if !cal.isDate(newDate, equalTo: displayedMonth, toGranularity: .month) {
                displayedMonth = cal.startOfMonth(for: newDate)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let day = selectedDay {
            DayExerciseList(day: day)
        } else {
            ContentUnavailableView(
                "No workout scheduled",
                systemImage: "calendar",
                description: Text("Pick another date or import a CSV that covers \(formattedSelected).")
            )
        }
    }

    private var formattedSelected: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.locale = .current
        return df.string(from: selectedDate)
    }
}

// MARK: - Date strip

private struct DateStrip: View {
    let month: Date
    @Binding var selectedDate: Date
    let datesWithWorkouts: Set<Date>
    let completedDates: Set<Date>

    private var stripDays: [Date] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        var comps = cal.dateComponents([.year, .month], from: month)
        let monthDays: [Date] = range.compactMap { day -> Date? in
            comps.day = day
            return cal.date(from: comps).map { cal.startOfDay(for: $0) }
        }
        // Also surface the surrounding weeks, even when they spill into the adjacent months —
        // otherwise the strip dead-ends at the month boundaries and the previous/next week's
        // workouts are unreachable (e.g. on June 1 you couldn't scroll back into late May).
        guard let first = monthDays.first, let last = monthDays.last else { return monthDays }
        let prevWeek: [Date] = (1...7).reversed().compactMap { offset in
            cal.date(byAdding: .day, value: -offset, to: first).map { cal.startOfDay(for: $0) }
        }
        let nextWeek: [Date] = (1...7).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: last).map { cal.startOfDay(for: $0) }
        }
        return prevWeek + monthDays + nextWeek
    }

    private let today: Date = Calendar.current.startOfDay(for: .now)

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(stripDays, id: \.self) { date in
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
                .padding(.vertical, 8)
            }
            .onAppear { proxy.scrollTo(targetID(in: stripDays), anchor: .center) }
            .onChange(of: month) { _, _ in
                withAnimation { proxy.scrollTo(targetID(in: stripDays), anchor: .center) }
            }
            .onChange(of: selectedDate) { _, _ in
                withAnimation { proxy.scrollTo(targetID(in: stripDays), anchor: .center) }
            }
        }
    }

    private func targetID(in days: [Date]) -> Date {
        let cal = Calendar.current
        if let match = days.first(where: { cal.isDate($0, inSameDayAs: selectedDate) }) {
            return match
        }
        return days.first ?? selectedDate
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

    private var weekdayShort: String {
        DayPill.weekdayFormatter.string(from: date)
    }

    private var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(weekdayShort)
                .font(.caption2)
                .foregroundStyle(isSelected || isCompleted ? Color.white.opacity(0.9) : .secondary)
            Text("\(dayNumber)")
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(isSelected || isCompleted ? .white : .primary)
            Circle()
                .fill(dotColor)
                .frame(width: 5, height: 5)
        }
        .frame(width: 44, height: 64)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(fillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(todayRingColor, lineWidth: 1.5)
        )
        .contentShape(.rect(cornerRadius: 12))
    }

    private var todayRingColor: Color {
        // The ring marks "today". On the selected (accent) or completed (green) fill the day is
        // already obvious, and a blue ring there just clashes — use white, or nothing when selected.
        guard isToday, !isSelected else { return .clear }
        return isCompleted ? .white : .accentColor
    }

    private var fillColor: Color {
        if isSelected { return .accentColor }
        if isCompleted { return .green }
        return Color(.secondarySystemBackground)
    }

    private var dotColor: Color {
        // The selected day's accent fill hides completion, so surface it with a green dot there.
        // A completed, unselected day already reads green from its fill, so its dot is redundant.
        if isSelected {
            if isCompleted { return .green }
            return hasWorkout ? .white : .clear
        }
        if isCompleted { return .clear }
        return hasWorkout ? .accentColor : .clear
    }
}

// MARK: - Month / Year picker

private struct MonthYearPicker: View {
    @Binding var displayedMonth: Date

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
                    displayedMonth = date
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

// MARK: - Section grouping & rows

private struct DayExerciseList: View {
    let day: WorkoutDay

    private var groupedExercises: [(section: WorkoutSection, exercises: [PlannedExercise])] {
        let groups = Dictionary(grouping: day.exercises) { $0.workoutSection }
        return WorkoutSection.allCases.compactMap { section in
            guard let list = groups[section], !list.isEmpty else { return nil }
            let sorted = list.sorted { $0.orderIndex < $1.orderIndex }
            return (section, sorted)
        }
    }

    private var allExercises: [PlannedExercise] {
        groupedExercises.flatMap { $0.exercises }
    }

    var body: some View {
        List {
            ForEach(groupedExercises, id: \.section) { group in
                Section(group.section.displayName) {
                    ForEach(group.exercises) { exercise in
                        NavigationLink(value: exercise.persistentModelID) {
                            ExerciseRow(exercise: exercise)
                        }
                    }
                }
            }
        }
        .navigationDestination(for: PersistentIdentifier.self) { id in
            if let exercise = allExercises.first(where: { $0.persistentModelID == id }) {
                ExerciseDetailView(day: day, startingExercise: exercise)
            } else {
                Text("Exercise not found")
            }
        }
    }
}

private struct ExerciseRow: View {
    let exercise: PlannedExercise

    private var completedCount: Int {
        exercise.sets.filter { $0.completedAt != nil }.count
    }

    private var targetCount: Int {
        exercise.isTimeBased ? 1 : (exercise.targetSets ?? 1)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(completedCount)/\(targetCount)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(completedCount == targetCount ? .green : .secondary)
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        if let secs = exercise.durationSeconds {
            return formatDuration(secs)
        }
        let setsText = (exercise.targetSets.map(String.init) ?? "?")
        let repsText = exercise.targetReps ?? "?"
        var s = "\(setsText) × \(repsText)"
        if let w = exercise.targetWeight {
            s += " @ \(w.formatted(.number.precision(.fractionLength(0...2)))) kg"
        }
        return s
    }
}

// MARK: - Helpers

func formatDuration(_ seconds: Int) -> String {
    if seconds < 60 { return "\(seconds)s" }
    let m = seconds / 60
    let s = seconds % 60
    return s == 0 ? "\(m)m" : "\(m)m \(s)s"
}

private func clampSameDayOfMonth(from oldDate: Date, into newMonth: Date) -> Date {
    let cal = Calendar.current
    let day = cal.component(.day, from: oldDate)
    var comps = cal.dateComponents([.year, .month], from: newMonth)
    let range = cal.range(of: .day, in: .month, for: newMonth) ?? 1..<2
    comps.day = min(day, range.upperBound - 1)
    return cal.date(from: comps).map { cal.startOfDay(for: $0) } ?? newMonth
}

extension Calendar {
    fileprivate func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}
