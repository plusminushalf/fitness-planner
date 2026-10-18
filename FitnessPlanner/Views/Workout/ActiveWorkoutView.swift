import SwiftUI
import SwiftData
import UIKit
import Combine

/// The live workout: every exercise as a Hevy-style set table in one scroll.
struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var day: WorkoutDay

    @State private var countdown = Countdown()
    @State private var history: ExerciseHistoryIndex?
    @State private var toast: String?
    @State private var showingPicker = false
    @State private var expandedVideo: PersistentIdentifier?
    @State private var showingFinishConfirm = false
    @State private var showingDiscardConfirm = false
    @State private var showingSaveRoutine = false
    @State private var routineName = ""
    @State private var durationEdit: LoggedSet?
    @State private var progressName: String?
    @State private var summary: WorkoutSummary?
    @FocusState private var focus: SetField?

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(day: WorkoutDay) {
        self.day = day
    }

    private var groups: [(section: WorkoutSection, exercises: [PlannedExercise])] {
        let ordered = day.orderedExercises
        return WorkoutSection.allCases.compactMap { section in
            let list = ordered.filter { $0.workoutSection == section }
            return list.isEmpty ? nil : (section, list)
        }
    }

    private var isFinished: Bool { day.completedAt != nil }

    var body: some View {
        List {
            statsHeader
                .tableRow(top: 8, bottom: 12)

            if day.exercises.isEmpty {
                emptyWorkout
                    .tableRow(top: 24, bottom: 24)
            }

            ForEach(groups, id: \.section) { group in
                if group.section != .exercise {
                    ColumnLabel(group.section.displayName)
                        .tableRow(top: 16, bottom: 4)
                }
                ForEach(group.exercises) { exercise in
                    exerciseRows(exercise)
                }
            }

            footer
                .tableRow(top: 20, bottom: 32)
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 0)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(day.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom) {
            if countdown.isActive {
                CountdownBar(countdown: countdown) { finishCountdown() }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: countdown.isActive)
        .onReceive(ticker) { now in
            if countdown.tick(now: now) { finishCountdown() }
        }
        .onAppear {
            if history == nil { history = ExerciseHistoryIndex(context: context) }
        }
        .onDisappear { countdown.stop() }
        .sheet(isPresented: $showingPicker) {
            ExercisePickerView { specs in
                WorkoutFactory.append(specs, to: day, history: history, context: context)
            }
        }
        .sheet(item: $durationEdit) { set in
            DurationEditorView(seconds: set.durationSeconds ?? 0, title: set.isCompleted ? "Recorded time" : "Target time") {
                set.durationSeconds = $0
            }
        }
        .navigationDestination(item: $progressName) { name in
            ExerciseProgressView(name: name)
        }
        .fullScreenCover(item: $summary) { s in
            WorkoutSummaryView(day: day, summary: s) {
                summary = nil
                dismiss()
            }
        }
        .confirmationDialog("Finish workout?", isPresented: $showingFinishConfirm, titleVisibility: .visible) {
            Button("Finish workout") { finish() }
            Button("Keep logging", role: .cancel) {}
        } message: {
            let open = day.totalSetCount - day.completedSetCount
            Text("\(open) \(open == 1 ? "set isn't" : "sets aren't") checked off. They'll stay unlogged.")
        }
        .confirmationDialog(
            day.isManual == true ? "Discard this workout?" : "Reset this workout?",
            isPresented: $showingDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button(day.isManual == true ? "Discard workout" : "Clear logged sets", role: .destructive) { discard() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(day.isManual == true
                 ? "Every exercise and set in it will be deleted."
                 : "Logged weights and reps are cleared. The planned exercises stay.")
        }
        .alert("Save as routine", isPresented: $showingSaveRoutine) {
            TextField("Routine name", text: $routineName)
            Button("Save") { saveRoutine() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Exercises and the sets you did become the routine's targets.")
        }
        .toast($toast)
    }

    // MARK: - Header

    private var statsHeader: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            HStack(alignment: .top, spacing: 12) {
                StatPair(
                    label: "Duration",
                    value: durationText(now: ctx.date),
                    valueColor: day.startedAt != nil && !isFinished ? .brand : .primary
                )
                StatPair(label: "Volume", value: Fmt.volume(day.volume))
                StatPair(label: "Sets", value: "\(day.completedSetCount) of \(day.totalSetCount)")
            }
        }
    }

    private func durationText(now: Date) -> String {
        guard let secs = day.elapsedSeconds(now: now) else { return "Not started" }
        return isFinished ? Fmt.elapsed(secs) : Fmt.clock(secs)
    }

    private var emptyWorkout: some View {
        VStack(spacing: 8) {
            Image(systemName: "dumbbell")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("Get started")
                .font(.headline)
            Text("Add an exercise to start logging sets.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Exercise block

    @ViewBuilder
    private func exerciseRows(_ exercise: PlannedExercise) -> some View {
        let previous = history?.previousSession(for: exercise.name, before: day.date)
        let sets = exercise.orderedSets
        let labels = setLabels(for: sets)

        exerciseHeader(exercise)
            .tableRow(top: 14, bottom: 4)

        if let notes = exercise.notes, !notes.isEmpty {
            Text(notes)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .tableRow(top: 2, bottom: 2)
        }

        restRow(exercise)
            .tableRow(top: 2, bottom: 2)

        if expandedVideo == exercise.persistentModelID, let videoID = exercise.videoID {
            YouTubePlayerView(videoID: videoID)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 10, style: .continuous))
                .tableRow(top: 6, bottom: 6)
        }

        SetTableHeader(timeBased: exercise.isTimeBased)
            .tableRow(top: 6, bottom: 0)

        ForEach(Array(sets.enumerated()), id: \.element.persistentModelID) { index, set in
            SetRowView(
                entry: set,
                timeBased: exercise.isTimeBased,
                label: labels[index],
                previous: previous.flatMap { index < $0.sets.count ? $0.sets[index] : nil },
                targetWeight: exercise.targetWeight,
                targetReps: exercise.targetReps,
                isTiming: countdown.kind == .work && countdown.workSet?.persistentModelID == set.persistentModelID,
                focus: $focus,
                onToggle: { toggle(set, in: exercise, previous: previous, index: index) },
                onSetType: { set.kind = $0 },
                onDelete: { deleteSet(set) },
                onTimer: { toggleTimer(set, in: exercise) },
                onEditDuration: { durationEdit = set }
            )
            .tableRow(top: 0, bottom: 0, background: set.isCompleted ? Color.doneRowFill : Color.clear, separator: true)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) { deleteSet(set) } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }

        Button {
            WorkoutFactory.addSet(to: exercise, context: context)
        } label: {
            Label("Add Set", systemImage: "plus")
        }
        .buttonStyle(.secondary)
        .tableRow(top: 8, bottom: 10)
    }

    private func exerciseHeader(_ exercise: PlannedExercise) -> some View {
        HStack(spacing: 12) {
            Button {
                guard exercise.videoID != nil else {
                    progressName = exercise.name
                    return
                }
                withAnimation(.snappy) {
                    expandedVideo = expandedVideo == exercise.persistentModelID ? nil : exercise.persistentModelID
                }
            } label: {
                ExerciseAvatar(name: exercise.name, videoID: exercise.videoID, size: 44)
                    .overlay(alignment: .bottomTrailing) {
                        if exercise.videoID != nil {
                            Image(systemName: "play.circle.fill")
                                .font(.footnote)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.brand)
                                .offset(x: 2, y: 2)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(exercise.videoID != nil ? "Play form video" : "Exercise history")

            Button {
                progressName = exercise.name
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundStyle(Color.brand)
                        .multilineTextAlignment(.leading)
                    Text([exercise.muscle.displayName, exercise.targetSummary].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    progressName = exercise.name
                } label: {
                    Label("Exercise history", systemImage: "chart.xyaxis.line")
                }
                if exercise.videoID != nil {
                    Button {
                        expandedVideo = expandedVideo == exercise.persistentModelID ? nil : exercise.persistentModelID
                    } label: {
                        Label(expandedVideo == exercise.persistentModelID ? "Hide form video" : "Show form video",
                              systemImage: "play.rectangle")
                    }
                }
                Divider()
                Button { move(exercise, by: -1) } label: { Label("Move up", systemImage: "arrow.up") }
                    .disabled(!canMove(exercise, by: -1))
                Button { move(exercise, by: 1) } label: { Label("Move down", systemImage: "arrow.down") }
                    .disabled(!canMove(exercise, by: 1))
                Divider()
                Button(role: .destructive) {
                    withAnimation { context.delete(exercise) }
                } label: {
                    Label("Remove exercise", systemImage: "xmark")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel("\(exercise.name) options")
        }
    }

    private static let restOptions = [0, 30, 45, 60, 75, 90, 120, 150, 180, 240, 300]

    private func restRow(_ exercise: PlannedExercise) -> some View {
        Menu {
            Picker("Rest timer", selection: Binding(
                get: { exercise.restSeconds ?? 0 },
                set: { exercise.restSeconds = $0 == 0 ? nil : $0 }
            )) {
                ForEach(Self.restOptions + [exercise.restSeconds ?? 0].filter { !Self.restOptions.contains($0) }, id: \.self) { secs in
                    Text(secs == 0 ? "Off" : formatDuration(secs)).tag(secs)
                }
            }
        } label: {
            Label {
                Text("Rest timer: \(exercise.restSeconds.map(formatDuration) ?? "off")")
            } icon: {
                Image(systemName: "timer")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(exercise.restSeconds == nil ? Color.secondary : Color.brand)
            .frame(minHeight: 32)
        }
    }

    // MARK: - Footer & toolbar

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                showingPicker = true
            } label: {
                Label("Add Exercise", systemImage: "plus")
            }
            .buttonStyle(.primary)

            HStack(spacing: 12) {
                Button {
                    routineName = day.displayTitle
                    showingSaveRoutine = true
                } label: {
                    Label("Save as Routine", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.secondary)
                .disabled(day.exercises.isEmpty)

                Button {
                    showingDiscardConfirm = true
                } label: {
                    Text(day.isManual == true ? "Discard" : "Reset")
                }
                .buttonStyle(.secondary(.red))
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if isFinished {
                Label("Finished", systemImage: "checkmark.seal.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.doneGreen)
            } else {
                Button("Finish", action: finishTapped)
                    .font(.subheadline.weight(.bold))
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 8))
                    .controlSize(.small)
            }
        }
        ToolbarItemGroup(placement: .keyboard) {
            if case .weight(let id)? = focus {
                Button("Next") { focus = .reps(id) }
            }
            Spacer()
            Button("Done") { focus = nil }
                .fontWeight(.semibold)
        }
    }

    // MARK: - Set actions

    private func setLabels(for sets: [LoggedSet]) -> [String] {
        var n = 0
        return sets.map { set in
            if set.kind == .warmup { return "W" }
            n += 1
            return set.kind.badge ?? "\(n)"
        }
    }

    private func toggle(_ set: LoggedSet, in exercise: PlannedExercise, previous: ExerciseSession?, index: Int) {
        if set.isCompleted {
            set.completedAt = nil
            return
        }
        let prior = previous.flatMap { index < $0.sets.count ? $0.sets[index] : nil }
        if exercise.isTimeBased {
            if set.durationSeconds == nil { set.durationSeconds = exercise.durationSeconds }
        } else {
            // Like Hevy: an untouched field takes the value it was showing as a placeholder.
            if set.weight == 0 {
                if let w = prior?.weight, w > 0 { set.weight = w } else if let w = exercise.targetWeight { set.weight = w }
            }
            if set.reps == 0 {
                if let r = prior?.reps, r > 0 { set.reps = r } else if let r = firstInteger(in: exercise.targetReps) { set.reps = r }
            }
            guard set.reps > 0 else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                toast = "Enter reps to complete the set"
                focus = .reps(set.persistentModelID)
                return
            }
        }
        complete(set, in: exercise)
    }

    private func complete(_ set: LoggedSet, in exercise: PlannedExercise) {
        focus = nil
        set.completedAt = .now
        if day.startedAt == nil { day.startedAt = .now }

        if let history {
            var records = history.records(for: exercise.name, before: day.date)
            let earlier = exercise.completedSets.filter { $0.persistentModelID != set.persistentModelID }
            if !records.isEmpty, !earlier.isEmpty {
                records.absorb(ExerciseSession(exercise: exercise, day: day, sets: earlier))
            }
            if let hit = records.beaten(by: set, timeBased: exercise.isTimeBased).first {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                let value: Double = switch hit {
                case .heaviestWeight: set.weight
                case .bestOneRepMax: set.estimatedOneRepMax ?? 0
                case .bestSetVolume: set.volume
                case .mostReps: Double(set.reps)
                case .longestDuration: Double(set.durationSeconds ?? 0)
                }
                toast = "New record · \(hit.displayName) \(hit.format(value))"
            }
        }

        if let rest = exercise.restSeconds, rest > 0 {
            countdown.start(.rest, seconds: rest, label: nextUpLabel(after: set, in: exercise))
        }
    }

    private func nextUpLabel(after set: LoggedSet, in exercise: PlannedExercise) -> String {
        if let next = exercise.orderedSets.first(where: { !$0.isCompleted && $0.persistentModelID != set.persistentModelID }) {
            return "\(exercise.name) · set \(next.setNumber)"
        }
        let ordered = day.orderedExercises
        if let i = ordered.firstIndex(where: { $0.persistentModelID == exercise.persistentModelID }),
           let next = ordered.dropFirst(i + 1).first {
            return next.name
        }
        return "Last set done"
    }

    private func toggleTimer(_ set: LoggedSet, in exercise: PlannedExercise) {
        if countdown.kind == .work, countdown.workSet?.persistentModelID == set.persistentModelID {
            // Stopped early: record what was actually held.
            let held = countdown.totalSeconds - countdown.remaining()
            countdown.stop()
            set.durationSeconds = max(1, held)
            complete(set, in: exercise)
            return
        }
        let secs = set.durationSeconds ?? exercise.durationSeconds ?? 60
        set.durationSeconds = secs
        if day.startedAt == nil { day.startedAt = .now }
        countdown.start(.work, seconds: secs, label: exercise.name, workSet: set)
    }

    private func finishCountdown() {
        let finishedSet = countdown.kind == .work ? countdown.workSet : nil
        countdown.stop()
        if let set = finishedSet, let exercise = set.exercise, !set.isCompleted {
            complete(set, in: exercise)
        }
    }

    private func deleteSet(_ set: LoggedSet) {
        if countdown.workSet?.persistentModelID == set.persistentModelID { countdown.stop() }
        withAnimation { WorkoutFactory.delete(set, context: context) }
    }

    private func firstInteger(in text: String?) -> Int? {
        guard let text else { return nil }
        let digits = text.prefix { $0.isNumber }
        return Int(digits)
    }

    // MARK: - Exercise order

    private func neighbour(of exercise: PlannedExercise, by offset: Int) -> PlannedExercise? {
        let ordered = day.orderedExercises
        guard let i = ordered.firstIndex(where: { $0.persistentModelID == exercise.persistentModelID }) else { return nil }
        let j = i + offset
        guard ordered.indices.contains(j), ordered[j].workoutSection == exercise.workoutSection else { return nil }
        return ordered[j]
    }

    private func canMove(_ exercise: PlannedExercise, by offset: Int) -> Bool {
        neighbour(of: exercise, by: offset) != nil
    }

    private func move(_ exercise: PlannedExercise, by offset: Int) {
        guard let other = neighbour(of: exercise, by: offset) else { return }
        // Renumber first so swapping works even when CSV order indices collide.
        for (i, e) in day.orderedExercises.enumerated() { e.orderIndex = i }
        withAnimation {
            let tmp = exercise.orderIndex
            exercise.orderIndex = other.orderIndex
            other.orderIndex = tmp
        }
    }

    // MARK: - Workout actions

    private func finishTapped() {
        guard day.completedSetCount > 0 else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            toast = "Check off at least one set to finish"
            return
        }
        if day.completedSetCount < day.totalSetCount {
            showingFinishConfirm = true
        } else {
            finish()
        }
    }

    private func finish() {
        countdown.stop()
        focus = nil
        let now = Date.now
        if day.startedAt == nil {
            day.startedAt = day.completedSets.compactMap(\.completedAt).min() ?? now
        }
        day.completedAt = now
        day.durationSeconds = day.elapsedSeconds(now: now)
        try? context.save()

        let index = ExerciseHistoryIndex(context: context)
        let all = (try? context.fetch(FetchDescriptor<WorkoutDay>())) ?? []
        let number = all.filter { $0.hasLoggedWork && $0.date <= day.date }.count
        summary = WorkoutSummary(records: index.recordHits(in: day), workoutNumber: number)
    }

    private func discard() {
        countdown.stop()
        if day.isManual == true {
            dismiss()
            let doomed = day
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                context.delete(doomed)
                try? context.save()
            }
        } else {
            for exercise in day.exercises {
                for set in exercise.sets {
                    set.completedAt = nil
                    set.kind = .normal
                    if exercise.isTimeBased {
                        set.durationSeconds = exercise.durationSeconds
                    } else {
                        set.weight = 0
                        set.reps = 0
                    }
                }
            }
            day.startedAt = nil
            day.completedAt = nil
            day.durationSeconds = nil
            toast = "Workout reset"
        }
    }

    private func saveRoutine() {
        let name = routineName.trimmingCharacters(in: .whitespacesAndNewlines)
        WorkoutFactory.makeRoutine(from: day, name: name.isEmpty ? day.displayTitle : name, context: context)
        toast = "Routine saved"
    }
}

// MARK: - Row styling

private extension View {
    /// Flat, separator-less list row with the table's horizontal inset.
    /// Set rows get hairlines between them so the table reads as a ledger.
    func tableRow(top: CGFloat, bottom: CGFloat, background: Color = .clear, separator: Bool = false) -> some View {
        self
            .listRowInsets(EdgeInsets(top: top, leading: 12, bottom: bottom, trailing: 8))
            .listRowSeparator(separator ? .visible : .hidden)
            .listRowSeparatorTint(Color(.separator))
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            .listRowBackground(background)
    }
}

// MARK: - Countdown bar

/// Bottom bar for rest and timed sets: −15 / time / +15 / Skip.
struct CountdownBar: View {
    let countdown: Countdown
    let onSkip: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { ctx in
            VStack(spacing: 10) {
                ProgressView(value: countdown.progress(at: ctx.date))
                    .tint(countdown.kind == .rest ? Color.brand : Color.doneGreen)
                HStack(spacing: 10) {
                    Button("−15s") { countdown.adjust(by: -15) }
                        .buttonStyle(.secondary)
                        .frame(width: 72)
                    VStack(spacing: 0) {
                        Text(countdown.kind == .rest ? "Rest" : countdown.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(Fmt.clock(countdown.remaining(at: ctx.date)))
                            .font(.title2.weight(.bold).monospacedDigit())
                            .contentTransition(.numericText(countsDown: true))
                    }
                    .frame(maxWidth: .infinity)
                    Button("+15s") { countdown.adjust(by: 15) }
                        .buttonStyle(.secondary)
                        .frame(width: 72)
                    Button(countdown.kind == .rest ? "Skip" : "Done", action: onSkip)
                        .buttonStyle(.primary)
                        .frame(width: 76)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(.bar)
            .accessibilityElement(children: .contain)
        }
    }
}

/// What the finish screen needs beyond the day itself.
struct WorkoutSummary: Identifiable {
    let id = UUID()
    let records: [RecordHit]
    let workoutNumber: Int
}
