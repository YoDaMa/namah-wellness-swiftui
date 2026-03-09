import SwiftUI
import SwiftData

struct LearnView: View {
    let cycleService: CycleService

    @Query(sort: \Phase.dayStart) private var phases: [Phase]
    @Query private var phaseNutrients: [PhaseNutrient]
    @Query private var reminders: [PhaseReminder]

    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Hormones card
                    NavigationLink {
                        HormonesView(cycleService: cycleService)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "flask")
                                .font(.system(size: 20))
                                .foregroundStyle(.phaseO)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Hormones")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                Text("Reference curves scaled to your cycle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    // Phase education
                    Text("PHASE GUIDE")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .textCase(.uppercase)
                        .tracking(2)
                        .foregroundStyle(.secondary)

                    ForEach(phases, id: \.id) { phase in
                        phaseEducationCard(phase)
                    }
                }
                .padding()
            }
            .navigationTitle("Learn")
            .sheet(isPresented: $showProfile) {
                NavigationStack {
                    ProfileView(cycleService: cycleService)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showProfile = true
                    } label: {
                        Image(systemName: "person.circle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func phaseEducationCard(_ phase: Phase) -> some View {
        let colors = PhaseColors.forSlug(phase.slug)
        let nutrients = phaseNutrients.filter { $0.phaseId == phase.id }
        let phaseReminders = reminders.filter { $0.phaseId == phase.id }

        return VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Circle()
                    .fill(colors.color)
                    .frame(width: 10, height: 10)
                Text(phase.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Days \(phase.dayStart)\u{2013}\(phase.dayEnd)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Title and subtitle
            Text(phase.heroTitle)
                .font(.headingMedium(20))
                .foregroundStyle(.primary)

            Text(phase.heroSubtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Key nutrients
            if !nutrients.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(nutrients, id: \.id) { nut in
                            HStack(spacing: 4) {
                                phaseIcon(nut.icon)
                                Text(nut.label)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(colors.soft)
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            // Reminders
            if !phaseReminders.isEmpty {
                ForEach(phaseReminders, id: \.id) { reminder in
                    HStack(alignment: .top, spacing: 8) {
                        phaseIcon(reminder.icon)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(reminder.text)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)

                            if let level = reminder.evidenceLevel, !level.isEmpty {
                                Text(evidenceLabel(level))
                                    .font(.system(size: 8, weight: .medium))
                                    .tracking(0.5)
                                    .foregroundStyle(evidenceColor(level))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(evidenceColor(level).opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(colors.soft)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func phaseIcon(_ name: String) -> some View {
        if UIImage(systemName: name) != nil {
            Image(systemName: name)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .center)
        } else {
            Text(name)
                .frame(width: 24, alignment: .center)
        }
    }

    private func evidenceLabel(_ level: String) -> String {
        switch level {
        case "strong": return "STRONG EVIDENCE"
        case "moderate": return "MODERATE EVIDENCE"
        case "emerging": return "EMERGING RESEARCH"
        case "expert_opinion": return "EXPERT OPINION"
        default: return level.uppercased()
        }
    }

    private func evidenceColor(_ level: String) -> Color {
        switch level {
        case "strong": return .phaseF
        case "moderate": return .phaseO
        case "emerging": return .phaseL
        default: return .secondary
        }
    }
}
