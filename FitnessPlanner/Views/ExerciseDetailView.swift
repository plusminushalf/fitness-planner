import SwiftUI
import SwiftData
import UIKit

struct ExerciseDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let day: WorkoutDay
    @State private var currentExercise: PlannedExercise
    @State private var showingCelebration = false

    init(day: WorkoutDay, startingExercise: PlannedExercise) {
        self.day = day
        self._currentExercise = State(initialValue: startingExercise)
    }

    private var sortedExercises: [PlannedExercise] {
        let grouped = Dictionary(grouping: day.exercises) { $0.workoutSection }
        return WorkoutSection.allCases.flatMap { section -> [PlannedExercise] in
            (grouped[section] ?? []).sorted { $0.orderIndex < $1.orderIndex }
        }
    }

    private var currentIndex: Int? {
        sortedExercises.firstIndex { $0.persistentModelID == currentExercise.persistentModelID }
    }

    private var isLast: Bool {
        guard let idx = currentIndex else { return true }
        return idx == sortedExercises.count - 1
    }

    private var nextExercise: PlannedExercise? {
        guard let idx = currentIndex, idx + 1 < sortedExercises.count else { return nil }
        return sortedExercises[idx + 1]
    }

    var body: some View {
        ExerciseStageView(
            exercise: currentExercise,
            nextExercise: nextExercise,
            isLast: isLast,
            onAdvance: advance,
            onCompleteWorkout: completeWorkout
        )
        .id(currentExercise.persistentModelID)
        .navigationTitle(currentExercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingCelebration) {
            WorkoutCompleteView(day: day) {
                showingCelebration = false
                dismiss()
            }
        }
    }

    private func advance() {
        markAllSetsCompleted(on: currentExercise)
        guard let next = nextExercise else { return }
        currentExercise = next
    }

    private func completeWorkout() {
        markAllSetsCompleted(on: currentExercise)
        day.completedAt = .now
        showingCelebration = true
    }

    private func markAllSetsCompleted(on exercise: PlannedExercise) {
        for set in exercise.sets where set.completedAt == nil {
            set.completedAt = .now
            if exercise.isTimeBased, set.durationSeconds == nil {
                set.durationSeconds = exercise.durationSeconds
            }
        }
    }
}

private enum RunnerPhase {
    case notStarted
    case running
    case resting
    case finished
}

private enum RestPending {
    case none
    case resumeRunning
    case advanceExercise
}

private struct ExerciseStageView: View {
    @Environment(\.modelContext) private var context
    @Bindable var exercise: PlannedExercise
    let nextExercise: PlannedExercise?
    let isLast: Bool
    let onAdvance: () -> Void
    let onCompleteWorkout: () -> Void

    @State private var phase: RunnerPhase = .notStarted
    @State private var remainingSeconds: Int = 0
    @State private var restRemaining: Int = 0
    @State private var restPending: RestPending = .none
    @State private var isVideoPlaying: Bool = true
    @State private var inputStage: SetInputStage = .weight
    @State private var ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var transientMessage: String?

    private var sortedSets: [LoggedSet] {
        exercise.sets.sorted { $0.setNumber < $1.setNumber }
    }

    private var completedSets: [LoggedSet] {
        sortedSets.filter { $0.completedAt != nil }
    }

    private var activeSet: LoggedSet? {
        sortedSets.first { $0.completedAt == nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                videoSection
                if let notes = exercise.notes, !notes.isEmpty {
                    notesCard(notes)
                }
                targetCard
                contentForPhase
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            bottomBar
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.regularMaterial)
        }
        .onAppear {
            if let secs = exercise.durationSeconds {
                remainingSeconds = secs
            }
        }
        .onReceive(ticker) { _ in
            tickTimer()
        }
        .overlay(alignment: .top) {
            if let msg = transientMessage {
                Text(msg)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private var videoSection: some View {
        if let raw = exercise.videoURL?.trimmingCharacters(in: .whitespaces), !raw.isEmpty {
            if let videoID = YouTubeURL.videoID(from: raw) {
                YouTubePlayerView(videoID: videoID, isPlaying: $isVideoPlaying)
                    .aspectRatio(16.0/9.0, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 8))
            } else {
                Label("Invalid video URL", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .padding(8)
                    .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 6))
            }
        }
    }

    private func notesCard(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 8))
    }

    private var targetCard: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Target")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(targetTitle)
                    .font(.title3.bold())
            }
            Spacer()
            if !exercise.isTimeBased, let w = exercise.targetWeight {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Weight")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(w.formatted(.number.precision(.fractionLength(0...2)))) kg")
                        .font(.title3.bold())
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 8))
    }

    private var targetTitle: String {
        if let secs = exercise.durationSeconds {
            return formatDuration(secs)
        }
        let setsText = exercise.targetSets.map(String.init) ?? "?"
        let repsText = exercise.targetReps ?? "?"
        return "\(setsText) × \(repsText)"
    }

    @ViewBuilder
    private var contentForPhase: some View {
        switch phase {
        case .notStarted:
            EmptyView()
        case .running:
            if exercise.isTimeBased {
                timerDisplay
            } else {
                steppedInputSection
            }
        case .resting:
            restDisplay
        case .finished:
            timerDoneCard
        }
    }

    private var restDisplay: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text(formatDuration(restRemaining))
                    .font(.system(size: 80, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.primary)
                Text("Rest")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if restPending == .advanceExercise, let next = nextExercise {
                NextExercisePreview(exercise: next)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var timerDisplay: some View {
        VStack(spacing: 8) {
            Text(formatDuration(remainingSeconds))
                .font(.system(size: 80, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)
            Text("Remaining")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var timerDoneCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            Text("Done")
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var steppedInputSection: some View {
        VStack(spacing: 12) {
            if !completedSets.isEmpty {
                VStack(spacing: 6) {
                    ForEach(completedSets) { set in
                        CompletedSetSummaryRow(set: set)
                    }
                    Button {
                        resetAllCompletedSets()
                    } label: {
                        Text("Reset all")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            if let active = activeSet {
                ActiveSetInputView(set: active, stage: inputStage) {
                    inputStage = .weight
                }
            }
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        switch phase {
        case .notStarted:
            Button {
                start()
            } label: {
                Text("Start exercise")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
        case .running:
            if exercise.isTimeBased {
                Button {
                    skip()
                } label: {
                    Text("Skip")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            } else {
                steppedBottomBar
            }
        case .resting:
            Button {
                finishRest()
            } label: {
                Text("Skip rest")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
        case .finished:
            advanceButton
        }
    }

    private var hasReachedTargetSets: Bool {
        guard let target = exercise.targetSets else { return true }
        return completedSets.count + 1 >= target
    }

    private var activeWeightIsValid: Bool {
        (activeSet?.weight ?? 0) > 0
    }

    private var activeRepsAreValid: Bool {
        (activeSet?.reps ?? 0) > 0
    }

    @ViewBuilder
    private var steppedBottomBar: some View {
        switch inputStage {
        case .weight:
            Button {
                guard activeWeightIsValid else {
                    flash("Add a weight greater than 0")
                    return
                }
                inputStage = .reps
            } label: {
                Text("Add weight")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
        case .reps:
            if hasReachedTargetSets {
                VStack(spacing: 6) {
                    Button {
                        guard activeRepsAreValid else {
                            flash("Add at least 1 rep")
                            return
                        }
                        completeActiveSetAndContinue()
                    } label: {
                        Text("Add reps")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        guard activeRepsAreValid else {
                            flash("Add at least 1 rep")
                            return
                        }
                        completeActiveSetAndAdvance()
                    } label: {
                        Text(isLast ? "Complete workout" : "Complete & Next")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isLast ? .green : .accentColor)
                }
            } else {
                Button {
                    guard activeRepsAreValid else {
                        flash("Add at least 1 rep")
                        return
                    }
                    completeActiveSetAndContinue()
                } label: {
                    Text("Add reps")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var advanceButton: some View {
        Button {
            advance()
        } label: {
            Text(isLast ? "Complete workout" : "Complete & Next")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(isLast ? .green : .accentColor)
    }

    private func start() {
        if exercise.isTimeBased {
            isVideoPlaying = false
            remainingSeconds = exercise.durationSeconds ?? 0
            ensureInitialSet()
        } else {
            ensureInitialSet()
            inputStage = activeSet.map { $0.weight > 0 ? .reps : .weight } ?? .weight
        }
        phase = .running
    }

    private func skip() {
        phase = .finished
    }

    private func advance() {
        if isLast {
            onCompleteWorkout()
        } else if exercise.restSeconds != nil {
            startRest(.advanceExercise)
        } else {
            onAdvance()
        }
    }

    private func startRest(_ pending: RestPending) {
        guard let secs = exercise.restSeconds, secs > 0 else {
            runPending(pending)
            return
        }
        restPending = pending
        restRemaining = secs
        phase = .resting
    }

    private func finishRest() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let pending = restPending
        restPending = .none
        restRemaining = 0
        runPending(pending)
    }

    private func runPending(_ pending: RestPending) {
        switch pending {
        case .none, .resumeRunning:
            phase = .running
        case .advanceExercise:
            onAdvance()
        }
    }

    private func tickTimer() {
        if phase == .running, exercise.isTimeBased, remainingSeconds > 0 {
            remainingSeconds -= 1
            if remainingSeconds == 0 {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                phase = .finished
            }
        } else if phase == .resting, restRemaining > 0 {
            restRemaining -= 1
            if restRemaining == 0 {
                finishRest()
            }
        }
    }

    private func ensureInitialSet() {
        guard exercise.sets.isEmpty else { return }
        let initial = LoggedSet(
            setNumber: 1,
            durationSeconds: exercise.isTimeBased ? exercise.durationSeconds : nil
        )
        initial.exercise = exercise
        context.insert(initial)
    }

    private func completeActiveSetAndContinue() {
        guard let active = activeSet else { return }
        active.completedAt = .now
        let next = LoggedSet(setNumber: active.setNumber + 1)
        next.exercise = exercise
        context.insert(next)
        inputStage = .weight
        if exercise.restSeconds != nil {
            startRest(.resumeRunning)
        }
    }

    private func completeActiveSetAndAdvance() {
        if let active = activeSet {
            active.completedAt = .now
        }
        advance()
    }

    private func resetAllCompletedSets() {
        for set in sortedSets {
            context.delete(set)
        }
        let fresh = LoggedSet(setNumber: 1)
        fresh.exercise = exercise
        context.insert(fresh)
        inputStage = .weight
    }

    private func flash(_ message: String) {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        withAnimation(.spring(duration: 0.3)) { transientMessage = message }
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) { transientMessage = nil }
            }
        }
    }
}

private struct NextExercisePreview: View {
    let exercise: PlannedExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Up next")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(alignment: .top, spacing: 12) {
                if let raw = exercise.videoURL?.trimmingCharacters(in: .whitespaces),
                   !raw.isEmpty,
                   let videoID = YouTubeURL.videoID(from: raw),
                   let thumbURL = URL(string: "https://img.youtube.com/vi/\(videoID)/mqdefault.jpg") {
                    AsyncImage(url: thumbURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color(.tertiarySystemBackground)
                    }
                    .frame(width: 96, height: 54)
                    .clipShape(.rect(cornerRadius: 6))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.headline)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let notes = exercise.notes?.trimmingCharacters(in: .whitespaces),
                       !notes.isEmpty {
                        Text(notes)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 10))
    }

    private var subtitle: String {
        if let secs = exercise.durationSeconds {
            return formatDuration(secs)
        }
        let setsText = exercise.targetSets.map(String.init) ?? "?"
        let repsText = exercise.targetReps ?? "?"
        var s = "\(setsText) × \(repsText)"
        if let w = exercise.targetWeight {
            s += " @ \(w.formatted(.number.precision(.fractionLength(0...2)))) kg"
        }
        return s
    }
}
