import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

/// Workout tab: the plan's schedule, the selected day's session, quick start and routines.
struct WorkoutHomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutPlan.importedAt, order: .reverse) private var plans: [WorkoutPlan]
    @Query(sort: \Routine.updatedAt, order: .reverse) private var routines: [Routine]
    @Query private var allDays: [WorkoutDay]

    @State private var path = NavigationPath()
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: .now)

    @State private var showingImporter = false
    @State private var importError: String?
    @State private var showingHistory = false
    @State private var showingResetConfirm = false
    @State private var toast: String?
    @State private var isProcessing = false
    @State private var processingMessage = ""
    @State private var shareItem: ShareItem?

    @State private var editingRoutine: RoutineEditorTarget?
    @State private var pendingRoutine: Routine?
    @State private var routineToDelete: Routine?

    private var plan: WorkoutPlan? { plans.first }
    private let today: Date = Calendar.current.startOfDay(for: .now)

    /// The current plan's days plus manual days that belong to no plan.
    private var scheduleDays: [WorkoutDay] {
        let planID = plan?.persistentModelID
        return allDays.filter { $0.plan == nil || $0.plan?.persistentModelID == planID }
    }

    /// Every session on the selected date: the planned one first, then free workouts.
    private var selectedDays: [WorkoutDay] {
        let cal = Calendar.current
        return scheduleDays
            .filter { cal.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { a, b in
                if (a.isManual == true) != (b.isManual == true) { return b.isManual == true }
                return (a.startedAt ?? .distantFuture) < (b.startedAt ?? .distantFuture)
            }
    }

    private var selectedDay: WorkoutDay? { selectedDays.first }

    private var stripDates: [Date] {
        let cal = Calendar.current
        let anchors = scheduleDays.map { cal.startOfDay(for: $0.date) } + [today]
        let lower = cal.startOfMonth(for: anchors.min() ?? today)
        let upperMonth = cal.startOfMonth(for: anchors.max() ?? today)
        // A week of padding either side keeps the neighbouring weeks reachable at the edges.
        guard
            let start = cal.date(byAdding: .day, value: -7, to: lower),
            let lastDayOfRange = cal.date(byAdding: DateComponents(month: 1, day: 6), to: upperMonth)
        else { return [] }
        var dates: [Date] = []
        var cursor = cal.startOfDay(for: start)
        let end = cal.startOfDay(for: lastDayOfRange)
        while cursor <= end {
            dates.append(cursor)
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return dates
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    DateStrip(
                        dates: stripDates,
                        selectedDate: $selectedDate,
                        datesWithWorkouts: Set(scheduleDays.map { Calendar.current.startOfDay(for: $0.date) }),
                        completedDates: Set(scheduleDays.filter { $0.completedAt != nil }.map { Calendar.current.startOfDay(for: $0.date) })
                    )

                    VStack(alignment: .leading, spacing: 24) {
                        if selectedDays.isEmpty {
                            restDayCard
                        } else {
                            ForEach(selectedDays) { day in
                                SessionCard(day: day, isToday: isSelectedToday) { open(day, start: true) }
                            }
                            Button {
                                startEmpty()
                            } label: {
                                Label("Start Empty Workout", systemImage: "plus")
                            }
                            .buttonStyle(.secondary(.brand))
                        }

                        if plan == nil {
                            importCard
                        }

                        routinesSection
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 32)
            }
            .background(Color.screenFill)
            .navigationTitle("Workout")
            .toolbar { toolbarContent }
            .navigationDestination(for: WorkoutDay.self) { day in
                ActiveWorkoutView(day: day)
            }
        }
        #if DEBUG
        .task { openDemoWorkoutIfRequested() }
        #endif
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                performImport(from: url)
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
        .alert("Import failed", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "")
        }
        .confirmationDialog("Reset all plans?", isPresented: $showingResetConfirm, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) { resetAllPlans() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes every imported plan and all logged sets. This can't be undone.")
        }
        .confirmationDialog(
            "Add to \(selectedDay?.displayTitle ?? "this workout")?",
            isPresented: Binding(get: { pendingRoutine != nil }, set: { if !$0 { pendingRoutine = nil } }),
            titleVisibility: .visible,
            presenting: pendingRoutine
        ) { routine in
            Button("Add \(routine.exercises.count) exercises") { start(routine) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This day already has a workout. The routine's exercises go after the ones already there.")
        }
        .confirmationDialog(
            "Delete \(routineToDelete?.name ?? "routine")?",
            isPresented: Binding(get: { routineToDelete != nil }, set: { if !$0 { routineToDelete = nil } }),
            titleVisibility: .visible,
            presenting: routineToDelete
        ) { routine in
            Button("Delete routine", role: .destructive) { context.delete(routine) }
        } message: { _ in
            Text("Workouts you already did from it are kept.")
        }
        .sheet(isPresented: $showingHistory) {
            PlanHistoryView()
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .sheet(item: $editingRoutine) { target in
            RoutineEditorView(routine: target.routine)
        }
        .toast($toast)
        .processingOverlay(isActive: isProcessing, message: processingMessage)
    }

    private var isSelectedToday: Bool {
        Calendar.current.isDate(selectedDate, inSameDayAs: today)
    }

    // MARK: - Sections

    private var restDayCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isSelectedToday ? "Nothing planned today" : "Nothing planned")
                    .font(.title3.weight(.bold))
                Text(plan == nil
                     ? "Start a workout from scratch, or load a plan below."
                     : "No session on \(Fmt.dayAndDate(selectedDate)). Rest, or train anyway.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button {
                startEmpty()
            } label: {
                Label("Start Empty Workout", systemImage: "plus")
            }
            .buttonStyle(.primary)
        }
        .card()
    }

    private var importCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Load a plan")
                    .font(.headline)
                Text("Copy a CSV plan on your Mac and paste it here, or import the file. Days land on their dates in the strip above.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Button {
                    pasteImport()
                } label: {
                    Label("Paste Plan", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.secondary(.brand))
                Button {
                    showingImporter = true
                } label: {
                    Label("Import File", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.secondary(.brand))
            }
        }
        .card()
    }

    private var routinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Routines")
                    .font(.title2.weight(.bold))
                Spacer()
                Button {
                    editingRoutine = RoutineEditorTarget(routine: nil)
                } label: {
                    Label("New Routine", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(minHeight: 44)
            }

            if routines.isEmpty {
                Text("Build a routine, or save any workout as one from its screen. Routines start on whichever day is selected above.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .card()
            } else {
                ForEach(routines) { routine in
                    RoutineCard(
                        routine: routine,
                        onStart: { requestStart(routine) },
                        onEdit: { editingRoutine = RoutineEditorTarget(routine: routine) },
                        onDelete: { routineToDelete = routine }
                    )
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            MonthYearPicker(displayedMonth: Calendar.current.startOfMonth(for: selectedDate)) { newMonth in
                selectedDate = clampSameDayOfMonth(from: selectedDate, into: newMonth)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if !isSelectedToday {
                Button("Today") { selectedDate = today }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    pasteImport()
                } label: {
                    Label("Paste plan from clipboard", systemImage: "doc.on.clipboard")
                }
                Button {
                    showingImporter = true
                } label: {
                    Label("Import CSV file…", systemImage: "square.and.arrow.down")
                }
                if let plan, CSVExporter.hasCompletedSets(in: plan) {
                    Divider()
                    Button {
                        copyProgress(for: plan)
                    } label: {
                        Label("Copy progress", systemImage: "doc.on.doc")
                    }
                    Button {
                        shareProgress(for: plan)
                    } label: {
                        Label("Share progress CSV…", systemImage: "square.and.arrow.up")
                    }
                }
                Divider()
                Button {
                    showingHistory = true
                } label: {
                    Label("Plan history", systemImage: "clock.arrow.circlepath")
                }
                Divider()
                Button(role: .destructive) {
                    showingResetConfirm = true
                } label: {
                    Label("Reset all plans", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Plan options")
        }
    }

    // MARK: - Starting workouts

    private func open(_ day: WorkoutDay, start: Bool) {
        if start, isSelectedToday, day.startedAt == nil, day.completedAt == nil {
            day.startedAt = .now
        }
        path.append(day)
    }

    /// Always a new free workout, even on a day that already has a planned session.
    private func startEmpty() {
        let day = WorkoutFactory.day(for: selectedDate, existing: nil, plan: plan, title: "Free workout", context: context)
        open(day, start: true)
    }

    private func requestStart(_ routine: Routine) {
        if let day = selectedDay, !day.exercises.isEmpty {
            pendingRoutine = routine
        } else {
            start(routine)
        }
    }

    private func start(_ routine: Routine) {
        pendingRoutine = nil
        let day = WorkoutFactory.day(for: selectedDate, existing: selectedDay, plan: plan, title: routine.name, context: context)
        if day.title == nil, day.exercises.isEmpty { day.title = routine.name }
        let history = ExerciseHistoryIndex(context: context)
        WorkoutFactory.append(routine.orderedExercises.map(ExerciseSpec.init(routineExercise:)), to: day, history: history, context: context)
        open(day, start: true)
    }

    #if DEBUG
    /// `-demoOpenToday YES`: open today's session with its first exercise half logged.
    private func openDemoWorkoutIfRequested() {
        guard UserDefaults.standard.bool(forKey: "demoOpenToday"), path.isEmpty, let day = selectedDay else { return }
        if let first = day.orderedExercises.first(where: { !$0.isTimeBased }) {
            for set in first.orderedSets.prefix(2) {
                set.weight = first.targetWeight ?? 20
                set.reps = 8
                set.completedAt = .now
            }
        }
        for warm in day.orderedExercises.filter({ $0.workoutSection == .warmup }) {
            if UserDefaults.standard.bool(forKey: "demoMainOnly") {
                context.delete(warm)
            } else {
                warm.sets.forEach { $0.completedAt = .now }
            }
        }
        day.startedAt = Date.now.addingTimeInterval(-1_250)
        path.append(day)
    }
    #endif

    // MARK: - Import / export

    private func performImport(from url: URL) {
        runWithLoader("Importing plan…") {
            try CSVImporter.importCSV(from: url, into: context)
            return "Plan imported"
        }
    }

    private func pasteImport() {
        guard let text = UIPasteboard.general.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            importError = "Clipboard is empty. Copy a CSV plan on your Mac first."
            return
        }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.locale = .current
        let name = "Pasted \(df.string(from: .now))"
        let current = plan
        runWithLoader("Importing plan…") {
            // Merge into the current plan: pasted days replace matching dates, days the plan
            // already has that aren't in the paste are kept. Falls back to a new plan if none.
            try CSVImporter.importContent(text, planName: name, into: context, mergeInto: current)
            return current == nil ? "Plan imported from clipboard" : "Plan updated from clipboard"
        }
    }

    private func copyProgress(for plan: WorkoutPlan) {
        runWithLoader("Building CSV…") {
            UIPasteboard.general.string = CSVExporter.makeCSV(from: plan)
            return "Progress copied to clipboard"
        }
    }

    private func shareProgress(for plan: WorkoutPlan) {
        runWithLoader("Preparing CSV…") {
            let url = try CSVExporter.writeToTempFile(for: plan)
            shareItem = ShareItem(url: url)
            return nil
        }
    }

    private func resetAllPlans() {
        let toDelete = plans
        runWithLoader("Deleting plans…") {
            for plan in toDelete { context.delete(plan) }
            try context.save()
            return "All plans cleared"
        }
    }

    /// Show the loader, give SwiftUI a tick to paint it, then run the work on the main actor.
    /// The work returns an optional toast string; nil means no toast.
    private func runWithLoader(_ message: String, work: @escaping () throws -> String?) {
        processingMessage = message
        isProcessing = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(60))
            defer { isProcessing = false }
            do {
                if let message = try work() { toast = message }
            } catch {
                importError = error.localizedDescription
            }
        }
    }
}

// MARK: - Session card

/// The selected day's workout, Hevy routine-card style: title, exercise lines, one action.
private struct SessionCard: View {
    let day: WorkoutDay
    let isToday: Bool
    let onOpen: () -> Void

    private var main: [PlannedExercise] {
        day.orderedExercises.filter { $0.workoutSection == .exercise }
    }

    private func others(_ section: WorkoutSection) -> [PlannedExercise] {
        day.orderedExercises.filter { $0.workoutSection == section }
    }

    private var subtitle: String {
        var parts = [isToday ? "Today" : Fmt.dayAndDate(day.date)]
        if let name = day.plan?.name, day.isManual != true { parts.append(name) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.displayTitle)
                        .font(.title3.weight(.bold))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                statusBadge
            }

            if day.status != .planned {
                HStack(spacing: 12) {
                    StatPair(label: "Time", value: day.elapsedSeconds().map(Fmt.elapsed) ?? "–")
                    StatPair(label: "Volume", value: Fmt.volume(day.volume))
                    StatPair(label: "Sets", value: "\(day.completedSetCount) of \(day.totalSetCount)")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                sectionLine(.warmup)
                ForEach(main.prefix(8)) { exercise in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(exercise.isTimeBased ? formatDuration(exercise.durationSeconds ?? 0) : "\(exercise.sets.count) ×")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 34, alignment: .leading)
                        Text(exercise.name)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        if !exercise.sets.isEmpty, exercise.sets.allSatisfy(\.isCompleted) {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.doneGreen)
                                .accessibilityLabel("Done")
                        }
                    }
                }
                if main.count > 8 {
                    Text("+ \(main.count - 8) more")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                sectionLine(.cooldown)
            }

            Button(action: onOpen) {
                Text(actionTitle)
            }
            .buttonStyle(.primary)
        }
        .card()
    }

    @ViewBuilder
    private func sectionLine(_ section: WorkoutSection) -> some View {
        let list = others(section)
        if !list.isEmpty {
            (Text("\(section.displayName)  ").fontWeight(.semibold) + Text(list.map(\.name).joined(separator: ", ")))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var actionTitle: String {
        switch day.status {
        case .planned: return day.exercises.isEmpty ? "Open Workout" : "Start Workout"
        case .inProgress: return "Resume Workout"
        case .completed: return "View Workout"
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch day.status {
        case .planned:
            EmptyView()
        case .inProgress:
            Text("In progress")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brand)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.brand.opacity(0.14), in: Capsule())
        case .completed:
            Label("Done", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.doneGreen)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.doneGreen.opacity(0.14), in: Capsule())
        }
    }
}

// MARK: - Routine card

private struct RoutineCard: View {
    let routine: Routine
    let onStart: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(routine.name)
                        .font(.headline)
                    Text(routine.orderedExercises.isEmpty
                         ? "No exercises yet"
                         : routine.orderedExercises.map(\.name).joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Menu {
                    Button(action: onEdit) { Label("Edit routine", systemImage: "pencil") }
                    Button(role: .destructive, action: onDelete) { Label("Delete routine", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .padding(.top, -10)
                .padding(.trailing, -12)
                .accessibilityLabel("\(routine.name) options")
            }
            Button(action: onStart) {
                Text("Start Routine")
            }
            .buttonStyle(.secondary(.brand))
            .disabled(routine.exercises.isEmpty)
        }
        .card()
        .contentShape(.rect)
        .contextMenu {
            Button(action: onEdit) { Label("Edit routine", systemImage: "pencil") }
            Button(role: .destructive, action: onDelete) { Label("Delete routine", systemImage: "trash") }
        }
    }
}

// MARK: - Sharing

struct RoutineEditorTarget: Identifiable {
    let id = UUID()
    let routine: Routine?
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
