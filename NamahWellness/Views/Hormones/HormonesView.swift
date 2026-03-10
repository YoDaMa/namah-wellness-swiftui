import SwiftUI

struct HormonesView: View {
    let cycleService: CycleService

    @State private var visible: [HormoneKey: Bool] = [.E2: true, .P4: true, .LH: true, .FSH: true]
    @State private var hoverDay: Int?
    @State private var expandedCards: Set<HormoneKey> = Set(HormoneKey.allCases)

    private var totalDays: Int { cycleService.cycleStats.avgCycleLength }
    private var displayDay: Int? { hoverDay ?? cycleService.currentPhase?.cycleDay }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let phase = cycleService.currentPhase {
                    PhaseHeaderView(phase: phase)
                }

                Text("Reference curves scaled to your \(totalDays)-day cycle.")
                    .font(.nSubheadline)
                    .foregroundStyle(.secondary)

                // Legend toggles
                legendRow

                // Chart
                HormoneChartView(
                    totalDays: totalDays,
                    visible: visible,
                    cycleDay: cycleService.currentPhase?.cycleDay,
                    phaseColor: cycleService.currentPhase.flatMap { PhaseColors.forSlug($0.phaseSlug).color },
                    phaseRanges: cycleService.phaseRanges,
                    hoverDay: $hoverDay
                )

                // Day detail panel
                if let day = displayDay {
                    dayDetailPanel(day: day)
                }

                // Hormone info cards
                ForEach(HormoneKey.allCases) { key in
                    if let meta = HormoneData.meta[key] {
                        hormoneCard(key: key, meta: meta)
                    }
                }

                // Disclaimer
                Text("These curves represent population averages from peer-reviewed reference ranges. Individual variation is significant. This is not a diagnostic tool.")
                    .font(.prose(11, relativeTo: .caption2))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("Hormones")
    }

    // MARK: - Legend

    private var legendRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HormoneKey.allCases) { key in
                    if let meta = HormoneData.meta[key] {
                        Button {
                            visible[key]?.toggle()
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(visible[key] == true ? meta.color : Color(uiColor: .separator))
                                    .frame(width: 8, height: 8)
                                Text(meta.fullName)
                                    .font(.nCaption2)
                                    .fontWeight(.medium)
                                    .textCase(.uppercase)
                                    .tracking(1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .foregroundStyle(visible[key] == true ? meta.color : .secondary)
                            .background(visible[key] == true ? meta.color.opacity(0.1) : .clear)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(visible[key] == true ? meta.color.opacity(0.3) : Color(uiColor: .separator), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Day Detail

    private func dayDetailPanel(day: Int) -> some View {
        let refDay = Int(round(Double(day - 1) / Double(totalDays - 1) * 27.0)) + 1

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Day \(day)")
                    .font(.nCaption2)
                    .fontWeight(.medium)
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundStyle(.primary)
                Spacer()
                if let date = calendarDate(for: day) {
                    Text(date)
                        .font(.nCaption2)
                        .foregroundStyle(.tertiary)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(HormoneKey.allCases) { key in
                    if visible[key] == true, let meta = HormoneData.meta[key] {
                        let desc = HormoneData.getDescriptor(key: key, day: refDay)
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(meta.color)
                                .frame(width: 8, height: 8)
                                .padding(.top, 3)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(meta.name)
                                    .font(.nCaption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                Text(desc.label)
                                    .font(.nCaption2)
                                    .foregroundStyle(.secondary)
                                Text(desc.range)
                                    .font(.nCaption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Hormone Cards

    private func hormoneCard(key: HormoneKey, meta: HormoneMeta) -> some View {
        DisclosureGroup(isExpanded: Binding(
            get: { expandedCards.contains(key) },
            set: { if $0 { expandedCards.insert(key) } else { expandedCards.remove(key) } }
        )) {
            VStack(alignment: .leading, spacing: 6) {
                Text(meta.description)
                    .font(.prose(13, relativeTo: .footnote))
                    .foregroundStyle(.primary)
                Text(meta.feel)
                    .font(.proseItalic(12, relativeTo: .caption))
                    .foregroundStyle(.secondary)
                Text(meta.peakLabel)
                    .font(.nCaption2)
                    .fontWeight(.medium)
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(meta.color)
                    .frame(width: 10, height: 10)
                Text(meta.fullName)
                    .font(.nSubheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Text(meta.unit)
                    .font(.nCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func calendarDate(for day: Int) -> String? {
        guard let startDate = cycleService.currentPhase?.periodStartDate else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let start = f.date(from: startDate),
              let date = Calendar.current.date(byAdding: .day, value: day - 1, to: start) else { return nil }
        let display = DateFormatter()
        display.dateFormat = "M/d"
        return display.string(from: date)
    }
}
