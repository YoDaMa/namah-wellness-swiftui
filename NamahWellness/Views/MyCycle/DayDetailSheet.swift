import SwiftUI
import SwiftData

struct DayDetailSheet: View {
    let day: CalendarDay
    let phaseRecord: Phase?
    let symptomLog: SymptomLog?
    let dailyNote: DailyNote?
    let bbtLog: BBTLog?
    let sexualActivityLogs: [SexualActivityLog]

    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService

    @Environment(\.dismiss) private var dismiss
    @State private var showEditTracking = false

    private var phaseSlug: String { day.phase?.phaseSlug ?? "menstrual" }
    private var colors: PhaseColors { PhaseColors.forSlug(phaseSlug) }
    private var isFutureDate: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        let today = formatter.string(from: Date())
        return day.id > today
    }

    /// Count of data categories logged for this day
    private var dataTypesLogged: Int {
        var count = 0
        if hasSymptomData { count += 1 }
        if hasFlowData { count += 1 }
        if bbtLog != nil { count += 1 }
        if !sexualActivityLogs.isEmpty { count += 1 }
        return count
    }

    private var hasSymptomData: Bool {
        guard let log = symptomLog else { return false }
        return [log.cramps, log.mood, log.energy, log.bloating, log.fatigue,
                log.headache, log.anxiety, log.irritability, log.sleepQuality,
                log.breastTenderness, log.acne, log.libido, log.appetite]
            .contains { $0 != nil }
    }

    private var hasFlowData: Bool {
        guard let flow = symptomLog?.flowIntensity else { return false }
        return flow != "none"
    }

    private var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        guard let date = formatter.date(from: day.id) else { return day.id }
        let display = DateFormatter()
        display.dateFormat = "EEEE, MMM d"
        return display.string(from: date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Motivational insight for rich logging days
                    if dataTypesLogged >= 3 {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text("Great logging! You tracked \(dataTypesLogged) categories.")
                                .font(.nCaption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Phase info card
                    phaseInfoCard

                    // BBT section
                    bbtSection

                    // Flow section
                    flowSection

                    // Symptoms section
                    symptomsBadgesSection

                    // Sexual activity section
                    sexualActivitySection

                    // Notes section
                    notesPreviewSection

                    // Edit button
                    if !isFutureDate {
                        Button {
                            showEditTracking = true
                        } label: {
                            Label("Edit Tracking Data", systemImage: "pencil")
                                .font(.nCaption)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(colors.color)
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(displayDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showEditTracking) {
                NavigationStack {
                    ScrollView {
                        DailyTrackingView(
                            symptomLog: symptomLog,
                            dailyNote: dailyNote,
                            bbtLog: bbtLog,
                            sexualActivityLogs: sexualActivityLogs,
                            date: day.id,
                            phaseSlug: phaseSlug
                        )
                        .padding()
                    }
                    .background(colors.soft.opacity(0.3))
                    .navigationTitle("Edit — \(displayDate)")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showEditTracking = false }
                        }
                    }
                }
                .presentationDragIndicator(.visible)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Phase Info Card

    @ViewBuilder
    private var phaseInfoCard: some View {
        if let phase = day.phase {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.white.opacity(0.8))
                        .frame(width: 8, height: 8)
                    Text(phase.phaseSlug.uppercased())
                        .font(.nCaption2)
                        .fontWeight(.bold)
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.8))

                    if phase.isProjected {
                        Text("· PROJECTED")
                            .font(.nCaption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()

                    Text("Day \(phase.dayInPhase) · Cycle day \(phase.cycleDay)")
                        .font(.nCaption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.6))
                }

                if let title = phaseRecord?.heroTitle {
                    Text(title)
                        .font(.display(20, relativeTo: .title3))
                        .foregroundStyle(.white)
                }

                if phase.isPeak {
                    Text("Peak Fertility")
                        .font(.nCaption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(colors.color)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - BBT Section

    private var bbtSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BASAL BODY TEMPERATURE")
                .namahLabel()

            if let bbt = bbtLog {
                HStack {
                    Image(systemName: "thermometer.medium")
                        .font(.title3)
                        .foregroundStyle(colors.color)

                    Text(String(format: "%.1f%@", bbt.temperature, bbt.unit.symbol))
                        .font(.display(24, relativeTo: .title3))

                    if let time = bbt.timeOfMeasurement {
                        Text("at \(time.formatted(date: .omitted, time: .shortened))")
                            .font(.nCaption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if isFutureDate {
                emptyState("Future date")
            } else {
                emptyState("No BBT recorded")
            }
        }
        .sectionCard()
    }

    // MARK: - Flow Section

    @ViewBuilder
    private var flowSection: some View {
        if hasFlowData, let flow = symptomLog?.flowIntensity {
            VStack(alignment: .leading, spacing: 8) {
                Text("FLOW")
                    .namahLabel()

                HStack(spacing: 8) {
                    let dots = flowDotCount(flow)
                    ForEach(0..<5) { i in
                        Circle()
                            .fill(i < dots ? Color.phaseM : Color.phaseM.opacity(0.2))
                            .frame(width: 10, height: 10)
                    }
                    Text(flow.capitalized)
                        .font(.nCaption)
                        .foregroundStyle(.secondary)
                }
            }
            .sectionCard()
        }
    }

    private func flowDotCount(_ flow: String) -> Int {
        switch flow {
        case "spotting": return 1
        case "light": return 2
        case "medium": return 3
        case "heavy": return 4
        default: return 0
        }
    }

    // MARK: - Symptoms Badges

    private var symptomsBadgesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SYMPTOMS")
                .namahLabel()

            if hasSymptomData, let log = symptomLog {
                let activeSymptoms = getActiveSymptoms(log)
                if !activeSymptoms.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(activeSymptoms, id: \.name) { symptom in
                            HStack(spacing: 4) {
                                Image(systemName: symptom.icon)
                                    .font(.system(size: 10))
                                Text("\(symptom.name) \(symptom.value)/5")
                                    .font(.nCaption2)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(colors.color.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                }
            } else if isFutureDate {
                emptyState("Future date")
            } else {
                emptyState("No symptoms logged")
            }
        }
        .sectionCard()
    }

    private struct ActiveSymptom {
        let name: String
        let icon: String
        let value: Int
    }

    private func getActiveSymptoms(_ log: SymptomLog) -> [ActiveSymptom] {
        let items: [(String, String, Int?)] = [
            ("Cramps", "waveform.path", log.cramps),
            ("Mood", "face.smiling", log.mood),
            ("Energy", "bolt.fill", log.energy),
            ("Bloating", "wind", log.bloating),
            ("Fatigue", "moon.zzz.fill", log.fatigue),
            ("Headache", "brain.head.profile", log.headache),
            ("Anxiety", "heart.text.clipboard", log.anxiety),
            ("Irritability", "flame.fill", log.irritability),
            ("Sleep", "moon.fill", log.sleepQuality),
            ("Tenderness", "heart.fill", log.breastTenderness),
            ("Acne", "circle.dotted", log.acne),
            ("Libido", "flame", log.libido),
            ("Appetite", "fork.knife", log.appetite),
        ]
        return items.compactMap { name, icon, value in
            guard let v = value else { return nil }
            return ActiveSymptom(name: name, icon: icon, value: v)
        }
    }

    // MARK: - Sexual Activity

    private var sexualActivitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SEXUAL ACTIVITY")
                .namahLabel()

            if !sexualActivityLogs.isEmpty {
                ForEach(sexualActivityLogs, id: \.id) { entry in
                    HStack(spacing: 10) {
                        Image(systemName: entry.protectionType.icon)
                            .font(.sans(14))
                            .foregroundStyle(colors.color)
                            .frame(width: 24)

                        Text(entry.protectionType.displayName)
                            .font(.nCaption)
                            .fontWeight(.medium)

                        if let time = entry.time {
                            Text(time.formatted(date: .omitted, time: .shortened))
                                .font(.nCaption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else if isFutureDate {
                emptyState("Future date")
            } else {
                emptyState("No activity logged")
            }
        }
        .sectionCard()
    }

    // MARK: - Notes Preview

    @ViewBuilder
    private var notesPreviewSection: some View {
        if let note = dailyNote, !note.content.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("NOTES")
                    .namahLabel()

                Text(note.content)
                    .font(.prose(13))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .sectionCard()
        }
    }

    // MARK: - Helpers

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.nCaption2)
            .foregroundStyle(.tertiary)
    }
}

// MARK: - Section card modifier

private extension View {
    func sectionCard() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
