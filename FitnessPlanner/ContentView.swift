import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutPlan.importedAt, order: .reverse) private var plans: [WorkoutPlan]

    @State private var showingImporter = false
    @State private var importError: String?
    @State private var showingHistory = false
    @State private var showingResetConfirm = false
    @State private var transientMessage: String?
    @State private var isProcessing = false
    @State private var processingMessage = ""
    @State private var shareItem: ShareItem?

    var body: some View {
        NavigationStack {
            Group {
                if let plan = plans.first {
                    TodayView(plan: plan)
                } else {
                    emptyState
                }
            }
            .navigationTitle("Fitness Planner")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        pasteImport()
                    } label: {
                        Label("Paste plan", systemImage: "doc.on.clipboard")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingImporter = true
                        } label: {
                            Label("Import CSV file…", systemImage: "square.and.arrow.down")
                        }
                        if let plan = plans.first, CSVExporter.hasCompletedSets(in: plan) {
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
                }
            }
        }
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
        .confirmationDialog(
            "Reset all plans?",
            isPresented: $showingResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete everything", role: .destructive) { resetAllPlans() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes every imported plan and all logged sets. This can't be undone.")
        }
        .sheet(isPresented: $showingHistory) {
            PlanHistoryView()
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
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
        .processingOverlay(isActive: isProcessing, message: processingMessage)
    }

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
        let name = defaultPlanName()
        let current = plans.first
        runWithLoader("Importing plan…") {
            // Merge into the current plan: pasted days replace matching dates, days the plan
            // already has that aren't in the paste are kept. Falls back to a new plan if none.
            try CSVImporter.importContent(text, planName: name, into: context, mergeInto: current)
            return current == nil ? "Plan imported from clipboard" : "Plan updated from clipboard"
        }
    }

    private func copyProgress(for plan: WorkoutPlan) {
        runWithLoader("Building CSV…") {
            let csv = CSVExporter.makeCSV(from: plan)
            UIPasteboard.general.string = csv
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
                if let toast = try work() {
                    flash(toast)
                }
            } catch {
                importError = error.localizedDescription
            }
        }
    }

    private func defaultPlanName() -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.locale = .current
        return "Pasted \(df.string(from: .now))"
    }

    private func flash(_ message: String) {
        withAnimation(.spring(duration: 0.3)) { transientMessage = message }
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) { transientMessage = nil }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "dumbbell")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No plan loaded")
                .font(.title2)
            Text("Paste a CSV from your Mac, or import a file to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            HStack(spacing: 12) {
                Button {
                    pasteImport()
                } label: {
                    Label("Paste plan", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    showingImporter = true
                } label: {
                    Label("Import file", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
            }
            .padding(.top)
        }
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

#Preview {
    ContentView()
        .modelContainer(for: [
            WorkoutPlan.self, WorkoutDay.self, PlannedExercise.self, LoggedSet.self,
        ], inMemory: true)
}
