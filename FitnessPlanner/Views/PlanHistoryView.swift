import SwiftUI
import SwiftData

struct PlanHistoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutPlan.importedAt, order: .reverse) private var plans: [WorkoutPlan]

    @State private var isDeleting = false

    var body: some View {
        NavigationStack {
            Group {
                if plans.isEmpty {
                    ContentUnavailableView(
                        "No plans yet",
                        systemImage: "calendar.badge.clock",
                        description: Text("Paste a CSV plan or import a file to see it here.")
                    )
                } else {
                    List {
                        ForEach(plans) { plan in
                            NavigationLink {
                                PlanDaysView(plan: plan)
                            } label: {
                                PlanHistoryRow(plan: plan)
                            }
                        }
                        .onDelete(perform: deletePlans)
                    }
                }
            }
            .navigationTitle("Plan History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .processingOverlay(isActive: isDeleting, message: "Deleting plan…")
    }

    private func deletePlans(at offsets: IndexSet) {
        let toDelete = offsets.map { plans[$0] }
        isDeleting = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(60))
            defer { isDeleting = false }
            for plan in toDelete {
                context.delete(plan)
            }
            try? context.save()
        }
    }
}

/// Every day of an older plan, each opening its workout.
private struct PlanDaysView: View {
    let plan: WorkoutPlan

    var body: some View {
        List(plan.days.sorted { $0.date < $1.date }) { day in
            NavigationLink {
                ActiveWorkoutView(day: day)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(day.displayTitle)
                            .font(.body.weight(.semibold))
                        Text("\(Fmt.dayAndDate(day.date)) · \(day.exercises.count) exercises")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if day.completedAt != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.doneGreen)
                            .accessibilityLabel("Done")
                    } else if day.hasLoggedWork {
                        Text("\(day.completedSetCount) of \(day.totalSetCount) sets")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PlanHistoryRow: View {
    let plan: WorkoutPlan

    private var dateRange: String? {
        let dates = plan.days.map(\.date)
        guard let first = dates.min(), let last = dates.max() else { return nil }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.locale = .current
        if Calendar.current.isDate(first, inSameDayAs: last) {
            return df.string(from: first)
        }
        return "\(df.string(from: first)) – \(df.string(from: last))"
    }

    private var importedAtString: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        df.locale = .current
        return "Imported \(df.string(from: plan.importedAt))"
    }

    private var summary: String {
        let dayCount = plan.days.count
        let exerciseCount = plan.days.reduce(0) { $0 + $1.exercises.count }
        let loggedCount = plan.days.reduce(0) { running, day in
            running + day.exercises.reduce(0) { ex, exercise in
                ex + exercise.sets.filter { $0.completedAt != nil }.count
            }
        }
        let daysPart = "\(dayCount) " + (dayCount == 1 ? "day" : "days")
        let exercisesPart = "\(exerciseCount) " + (exerciseCount == 1 ? "exercise" : "exercises")
        let setsPart = "\(loggedCount) " + (loggedCount == 1 ? "set" : "sets") + " logged"
        return "\(daysPart) · \(exercisesPart) · \(setsPart)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(plan.name)
                .font(.headline)
            if let range = dateRange {
                Text(range)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(importedAtString)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    PlanHistoryView()
        .modelContainer(for: [
            WorkoutPlan.self, WorkoutDay.self, PlannedExercise.self, LoggedSet.self,
            Routine.self, RoutineExercise.self,
        ], inMemory: true)
}
