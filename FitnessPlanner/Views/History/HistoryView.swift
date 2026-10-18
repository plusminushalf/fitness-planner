import SwiftUI
import SwiftData
import Charts

struct HistoryView: View {
    @Query(sort: \WorkoutDay.date, order: .reverse) private var days: [WorkoutDay]
    @State private var metric: WeeklyMetric = .volume

    var body: some View {
        let index = ExerciseHistoryIndex(days: days)
        let logged = days.filter(\.hasLoggedWork)
        NavigationStack {
            Group {
                if logged.isEmpty {
                    ContentUnavailableView(
                        "No workouts yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Finished sets show up here. Log your first set from the Workout tab.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            WeeklyChartCard(days: logged, metric: $metric)

                            ForEach(monthGroups(logged), id: \.month) { group in
                                Text(group.month.formatted(.dateTime.month(.wide).year()))
                                    .font(.headline)
                                    .padding(.top, 16)
                                    .accessibilityAddTraits(.isHeader)

                                ForEach(group.days) { day in
                                    NavigationLink {
                                        WorkoutDetailView(day: day)
                                    } label: {
                                        WorkoutHistoryCard(day: day, recordCount: index.recordHits(in: day).count)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.screenFill)
            .navigationTitle("History")
        }
    }

    private func monthGroups(_ days: [WorkoutDay]) -> [(month: Date, days: [WorkoutDay])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: days) { cal.startOfMonth(for: $0.date) }
        return grouped.keys.sorted(by: >).map { month in
            (month, grouped[month]!.sorted { $0.date > $1.date })
        }
    }
}

// MARK: - Weekly chart

enum WeeklyMetric: String, CaseIterable, Identifiable {
    case volume
    case sets
    case workouts
    case duration

    var id: String { rawValue }

    var label: String {
        switch self {
        case .volume: return "Volume"
        case .sets: return "Sets"
        case .workouts: return "Workouts"
        case .duration: return "Time"
        }
    }

    func value(for day: WorkoutDay) -> Double {
        switch self {
        case .volume: return day.volume
        case .sets: return Double(day.completedSetCount)
        case .workouts: return 1
        case .duration: return Double(day.elapsedSeconds() ?? 0) / 60
        }
    }

    func format(_ value: Double) -> String {
        switch self {
        case .volume: return Fmt.volume(value)
        case .sets:
            let n = Int(value)
            return "\(n) \(n == 1 ? "set" : "sets")"
        case .workouts:
            let n = Int(value)
            return "\(n) \(n == 1 ? "workout" : "workouts")"
        case .duration:
            let secs = Int(value * 60)
            return secs == 0 ? "0min" : Fmt.elapsed(secs)
        }
    }
}

private struct WeekBucket: Identifiable {
    let week: Date
    let value: Double
    let isCurrent: Bool
    var id: Date { week }
}

private struct WeeklyChartCard: View {
    let days: [WorkoutDay]
    @Binding var metric: WeeklyMetric

    private var cal: Calendar { Calendar.current }

    private var buckets: [WeekBucket] {
        let thisWeek = cal.startOfWeek(for: .now)
        var totals: [Date: Double] = [:]
        for day in days {
            totals[cal.startOfWeek(for: day.date), default: 0] += metric.value(for: day)
        }
        return (0..<12).reversed().compactMap { offset in
            guard let week = cal.date(byAdding: .weekOfYear, value: -offset, to: thisWeek) else { return nil }
            return WeekBucket(week: week, value: totals[week] ?? 0, isCurrent: offset == 0)
        }
    }

    /// Consecutive weeks with at least one workout, counting back from this week
    /// (or last week, so a streak isn't broken before this week's first session).
    private var streak: Int {
        let active = Set(days.map { cal.startOfWeek(for: $0.date) })
        var cursor = cal.startOfWeek(for: .now)
        if !active.contains(cursor) {
            guard let last = cal.date(byAdding: .weekOfYear, value: -1, to: cursor) else { return 0 }
            cursor = last
        }
        var count = 0
        while active.contains(cursor) {
            count += 1
            guard let prev = cal.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    var body: some View {
        let data = buckets
        let current = data.last?.value ?? 0
        VStack(alignment: .leading, spacing: 14) {
            Picker("Metric", selection: $metric) {
                ForEach(WeeklyMetric.allCases) { m in
                    Text(m.label).tag(m)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 2) {
                Text(metric.format(current))
                    .font(.title3.bold().monospacedDigit())
                    .contentTransition(.numericText())
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            Chart(data) { bucket in
                BarMark(
                    x: .value("Week", bucket.week, unit: .weekOfYear),
                    y: .value(metric.label, bucket.value)
                )
                .foregroundStyle(Color.brand.opacity(bucket.isCurrent ? 1 : 0.4))
                .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear, count: 3)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 160)
            .animation(.easeOut(duration: 0.25), value: metric)
        }
        .card()
    }

    private var caption: String {
        let s = streak
        guard s > 0 else { return "this week" }
        return "this week · \(s)-week streak"
    }
}

// MARK: - Workout card

private struct WorkoutHistoryCard: View {
    let day: WorkoutDay
    let recordCount: Int

    private var sessions: [ExerciseSession] {
        day.orderedExercises.compactMap { ex in
            let done = ex.completedSets
            return done.isEmpty ? nil : ExerciseSession(exercise: ex, day: day, sets: done)
        }
    }

    private var dateLine: String {
        var s = Fmt.dayAndDate(day.date)
        if let started = day.startedAt {
            s += " · " + started.formatted(date: .omitted, time: .shortened)
        }
        return s
    }

    var body: some View {
        let list = sessions
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.displayTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(dateLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 8) {
                StatPair(label: "Time", value: day.elapsedSeconds().map(Fmt.elapsed) ?? "—")
                StatPair(label: "Volume", value: Fmt.volume(day.volume))
                StatPair(label: "Sets", value: "\(day.completedSetCount)")
                RecordsStat(count: recordCount)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                ForEach(list.prefix(5)) { session in
                    HStack(spacing: 8) {
                        Text("\(session.sets.count) \(session.sets.count == 1 ? "set" : "sets")")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(minWidth: 52, alignment: .leading)
                        Text(session.exercise.name)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        if let best = session.bestSet {
                            Text(Fmt.set(best, timeBased: session.isTimeBased))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .lineLimit(1)
                        }
                    }
                    .font(.subheadline)
                }
                if list.count > 5 {
                    let more = list.count - 5
                    Text("+\(more) more \(more == 1 ? "exercise" : "exercises")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .card()
        .contentShape(.rect(cornerRadius: 12))
    }
}

/// The Records column: a trophy and count when this workout set any PRs.
struct RecordsStat: View {
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Records")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                if count > 0 {
                    Image(systemName: "trophy.fill")
                        .font(.caption)
                        .foregroundStyle(Color.recordGold)
                }
                Text("\(count)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
