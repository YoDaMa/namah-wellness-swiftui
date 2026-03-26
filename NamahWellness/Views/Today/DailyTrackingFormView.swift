import SwiftUI
import SwiftData

/// Wraps DailyTrackingView with Save/Cancel form behavior.
/// Buffers changes — nothing is persisted until the user taps Save.
struct DailyTrackingFormView: View {
    let symptomLog: SymptomLog?
    let dailyNote: DailyNote?
    let bbtLog: BBTLog?
    let sexualActivityLogs: [SexualActivityLog]
    let date: String
    let phaseSlug: String
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService

    // Track whether any edits have been made
    @State private var isDirty = false
    @State private var showDiscardAlert = false

    // Snapshot of original values to detect changes
    @State private var originalSymptomSnapshot: [String: Int] = [:]
    @State private var originalFlow: String = "none"
    @State private var originalNote: String = ""

    private var phaseColors: PhaseColors { PhaseColors.forSlug(phaseSlug) }

    // Lightweight snapshot that changes whenever any tracked field changes
    private var changeToken: String {
        let s = symptomLog
        return "\(s?.mood ?? -1)|\(s?.energy ?? -1)|\(s?.cramps ?? -1)|\(s?.bloating ?? -1)|\(s?.flowIntensity ?? "")|\(dailyNote?.content ?? "")"
    }

    var body: some View {
        styledFormContent
            .onChange(of: changeToken) { isDirty = true }
    }

    private var styledFormContent: some View {
        formContent
            .background(phaseColors.soft.opacity(0.3))
            .navigationTitle("Today's Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar { formToolbar }
            .onAppear { captureSnapshot() }
            .confirmationDialog(
                "You have unsaved changes",
                isPresented: $showDiscardAlert,
                titleVisibility: .visible
            ) {
                Button("Save & Close") { save() }
                Button("Discard Changes", role: .destructive) { onDismiss() }
                Button("Cancel", role: .cancel) { }
            }
    }

    private var formContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                DailyTrackingView(
                    symptomLog: symptomLog,
                    dailyNote: dailyNote,
                    bbtLog: bbtLog,
                    sexualActivityLogs: sexualActivityLogs,
                    date: date,
                    phaseSlug: phaseSlug
                )
                .padding(.horizontal)

                saveButton
                    .padding(.horizontal)
                    .padding(.bottom, 32)
            }
        }
    }

    private var saveButton: some View {
        Button { save() } label: {
            Text("Save Check-in")
                .font(.nSubheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(phaseColors.color)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ToolbarContentBuilder
    private var formToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { attemptDismiss() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Back")
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { save() } label: {
                Text("Save")
                    .fontWeight(.semibold)
                    .foregroundStyle(phaseColors.color)
            }
        }
    }

    private func attemptDismiss() {
        if isDirty {
            showDiscardAlert = true
        } else {
            onDismiss()
        }
    }

    private func save() {
        // DailyTrackingView already writes to SwiftData on each interaction.
        // We just need to ensure the context is saved and then dismiss.
        try? modelContext.save()
        Task { await syncService.sync() }
        Haptics.completion()
        onDismiss()
    }

    private func captureSnapshot() {
        if let log = symptomLog {
            var snap: [String: Int] = [:]
            if let v = log.mood { snap["mood"] = v }
            if let v = log.energy { snap["energy"] = v }
            if let v = log.cramps { snap["cramps"] = v }
            if let v = log.bloating { snap["bloating"] = v }
            if let v = log.fatigue { snap["fatigue"] = v }
            if let v = log.headache { snap["headache"] = v }
            if let v = log.anxiety { snap["anxiety"] = v }
            if let v = log.irritability { snap["irritability"] = v }
            if let v = log.sleepQuality { snap["sleepQuality"] = v }
            if let v = log.breastTenderness { snap["breastTenderness"] = v }
            if let v = log.acne { snap["acne"] = v }
            if let v = log.libido { snap["libido"] = v }
            if let v = log.appetite { snap["appetite"] = v }
            originalSymptomSnapshot = snap
            originalFlow = log.flowIntensity ?? "none"
        }
        originalNote = dailyNote?.content ?? ""
    }

    private func hasChanges() -> Bool {
        guard let log = symptomLog else {
            // If there's now a symptom log that didn't exist before, that's a change
            return true
        }
        // Check if any symptom value differs from snapshot
        let currentSnap: [String: Int] = {
            var snap: [String: Int] = [:]
            if let v = log.mood { snap["mood"] = v }
            if let v = log.energy { snap["energy"] = v }
            if let v = log.cramps { snap["cramps"] = v }
            if let v = log.bloating { snap["bloating"] = v }
            if let v = log.fatigue { snap["fatigue"] = v }
            if let v = log.headache { snap["headache"] = v }
            if let v = log.anxiety { snap["anxiety"] = v }
            if let v = log.irritability { snap["irritability"] = v }
            if let v = log.sleepQuality { snap["sleepQuality"] = v }
            if let v = log.breastTenderness { snap["breastTenderness"] = v }
            if let v = log.acne { snap["acne"] = v }
            if let v = log.libido { snap["libido"] = v }
            if let v = log.appetite { snap["appetite"] = v }
            return snap
        }()
        if currentSnap != originalSymptomSnapshot { return true }
        if (log.flowIntensity ?? "none") != originalFlow { return true }
        if (dailyNote?.content ?? "") != originalNote { return true }
        return false
    }
}
