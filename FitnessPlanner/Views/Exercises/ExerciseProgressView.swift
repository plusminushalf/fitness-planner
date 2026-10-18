import SwiftUI
import SwiftData
import Charts

/// Per-exercise progress: trend chart, personal records, form video, and every logged session.
struct ExerciseProgressView: View {
    let name: String

    @Query private var days: [WorkoutDay]
    @State private var metric: ProgressMetric?
    @State private var selectedDate: Date?
    @State private var showingVideo = false

    private var sessions: [ExerciseSession] {
        ExerciseHistoryIndex(days: days).sessions(for: name)
    }

    var body: some View {
        let sessions = self.sessions
        let isTimeBased = sessions.first?.isTimeBased ?? (ExerciseCatalog.entry(named: name)?.defaultDuration != nil)
        let latestExercise = sessions.first?.exercise

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(muscle: latestExercise?.muscle ?? ExerciseCatalog.muscle(for: name, stored: nil),
                       videoID: latestExercise?.videoID)

                if sessions.isEmpty {
                    ContentUnavailableView {
                        Label("No history yet", systemImage: "chart.xyaxis.line")
                    } description: {
                        Text("Sets you check off for \(name) will chart here.")
                    }
                    .padding(.top, 24)
                } else {
                    let metrics = ProgressMetric.available(timeBased: isTimeBased)
                    let current = metric.flatMap { metrics.contains($0) ? $0 : nil } ?? metrics[0]
                    chartCard(sessions: sessions, metrics: metrics, current: current)
                    recordsCard(sessions: sessions)
                    if let videoID = sessions.lazy.compactMap({ $0.exercise.videoID }).first {
                        videoCard(videoID: videoID)
                    }
                    historySection(sessions: sessions)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color.screenFill)
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Header

    private func header(muscle: MuscleGroup, videoID: String?) -> some View {
        HStack(spacing: 14) {
            ExerciseAvatar(name: name, videoID: videoID, size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.title2.bold())
                    .lineLimit(2)
                Text(muscle.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    // MARK: Chart

    private func chartCard(sessions: [ExerciseSession], metrics: [ProgressMetric], current: ProgressMetric) -> some View {
        let points: [ChartPoint] = sessions.reversed().compactMap { s in
            current.value(s).map { ChartPoint(date: s.date, value: $0) }
        }
        let selected = selectedDate.flatMap { date in
            points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
        }
        let shown = selected ?? points.last

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(shown.map { current.format($0.value) } ?? "–")
                        .font(.title3.bold().monospacedDigit())
                        .contentTransition(.numericText())
                    Text(caption(points: points, selected: selected, metric: current))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if metrics.count > 1 {
                    Menu {
                        Picker("Metric", selection: Binding(get: { current }, set: { metric = $0 })) {
                            ForEach(metrics) { Text($0.label).tag($0) }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(current.label)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2.weight(.semibold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                    }
                } else {
                    Text(current.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if points.isEmpty {
                Text("No \(current.label.lowercased()) logged yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart {
                    ForEach(points) { p in
                        LineMark(x: .value("Date", p.date), y: .value(current.label, p.value))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Color.brand)
                        PointMark(x: .value("Date", p.date), y: .value(current.label, p.value))
                            .foregroundStyle(Color.brand)
                            .symbolSize(selected?.id == p.id ? 90 : 30)
                    }
                    if let selected {
                        RuleMark(x: .value("Selected", selected.date))
                            .foregroundStyle(Color.secondary.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                }
                .chartXSelection(value: $selectedDate)
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .frame(height: 180)
                .accessibilityLabel("\(current.label) over time")
            }
        }
        .card()
    }

    private func caption(points: [ChartPoint], selected: ChartPoint?, metric: ProgressMetric) -> String {
        if let selected {
            return selected.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
        }
        guard let first = points.first, let last = points.last, points.count > 1 else {
            return points.isEmpty ? "No sessions" : "1 session"
        }
        let since = first.date.formatted(.dateTime.day().month(.abbreviated))
        return "\(metric.formatDelta(last.value - first.value)) since \(since)"
    }

    // MARK: Records

    private func recordsCard(sessions: [ExerciseSession]) -> some View {
        var records = PersonalRecords()
        for s in sessions.reversed() { records.absorb(s) }
        let kinds = RecordKind.allCases.filter { records.values[$0] != nil }

        return VStack(alignment: .leading, spacing: 0) {
            Text("Personal records")
                .font(.headline)
                .padding(.bottom, 8)
            ForEach(Array(kinds.enumerated()), id: \.element) { i, kind in
                if i > 0 { Divider() }
                HStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(Color.recordGold)
                        .font(.subheadline)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(kind.displayName)
                            .font(.subheadline)
                        if let date = records.dates[kind] {
                            Text(date.formatted(.dateTime.day().month(.abbreviated).year()))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(records.values[kind].map(kind.format) ?? "–")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
            }
        }
        .card()
    }

    // MARK: Video

    private func videoCard(videoID: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { showingVideo.toggle() }
            } label: {
                HStack {
                    Label("Form video", systemImage: "play.rectangle.fill")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showingVideo ? 180 : 0))
                }
                .frame(minHeight: 32)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityValue(showingVideo ? "Expanded" : "Collapsed")

            if showingVideo {
                YouTubePlayerView(videoID: videoID)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 8, style: .continuous))
            }
        }
        .card()
    }

    // MARK: History

    private func historySection(sessions: [ExerciseSession]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.title3.bold())
                .padding(.top, 8)
            ForEach(sessions) { session in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(Fmt.dayAndDate(session.date))
                            .font(.headline)
                        Spacer()
                        Text(session.day.displayTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    ForEach(Array(labeledSets(session.sets).enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 12) {
                            Text(item.label)
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(item.set.kind == .normal ? Color.secondary : item.set.kind.tint)
                                .frame(width: 24, alignment: .leading)
                            Text(Fmt.set(item.set, timeBased: session.isTimeBased))
                                .font(.subheadline.monospacedDigit())
                            Spacer()
                            if !session.isTimeBased, let e = item.set.estimatedOneRepMax, item.set.reps > 1 {
                                Text("1RM \(Fmt.number(e.rounded()))")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .card()
            }
        }
    }

    /// Working sets are numbered 1…n; warm-ups don't take a number. Typed sets show their letter.
    private func labeledSets(_ sets: [LoggedSet]) -> [(label: String, set: LoggedSet)] {
        var n = 0
        return sets.map { set in
            if set.kind != .warmup { n += 1 }
            return (set.kind.badge ?? "\(n)", set)
        }
    }
}

// MARK: - Metric

private struct ChartPoint: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

private enum ProgressMetric: String, CaseIterable, Identifiable {
    case heaviest
    case oneRepMax
    case setVolume
    case sessionVolume
    case longest

    var id: String { rawValue }

    static func available(timeBased: Bool) -> [ProgressMetric] {
        timeBased ? [.longest] : [.heaviest, .oneRepMax, .setVolume, .sessionVolume]
    }

    var label: String {
        switch self {
        case .heaviest: return "Heaviest weight"
        case .oneRepMax: return "Est. 1RM"
        case .setVolume: return "Best set volume"
        case .sessionVolume: return "Session volume"
        case .longest: return "Longest time"
        }
    }

    func value(_ s: ExerciseSession) -> Double? {
        switch self {
        case .heaviest: return s.heaviestWeight
        case .oneRepMax: return s.bestOneRepMax
        case .setVolume: return s.bestSetVolume
        case .sessionVolume: return s.volume > 0 ? s.volume : nil
        case .longest: return s.longestDuration.map(Double.init)
        }
    }

    func format(_ v: Double) -> String {
        switch self {
        case .heaviest, .oneRepMax: return Fmt.weight(v)
        case .setVolume, .sessionVolume: return Fmt.volume(v)
        case .longest: return formatDuration(Int(v))
        }
    }

    func formatDelta(_ d: Double) -> String {
        if abs(d) < 0.005 { return "No change" }
        let sign = d > 0 ? "+" : "−"
        return sign + format(abs(d))
    }
}

#Preview {
    NavigationStack {
        ExerciseProgressView(name: "Bench Press")
    }
    .modelContainer(for: [
        WorkoutPlan.self, WorkoutDay.self, PlannedExercise.self, LoggedSet.self,
        Routine.self, RoutineExercise.self,
    ], inMemory: true)
}
