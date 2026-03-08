import SwiftUI

struct HormonesView: View {
    let cycleService: CycleService

    @State private var visible: [HormoneKey: Bool] = [.E2: true, .P4: true, .LH: true, .FSH: true]
    @State private var hoverDay: Int?
    @State private var expandedCards: Set<HormoneKey> = Set(HormoneKey.allCases)

    private var totalDays: Int { cycleService.cycleStats.avgCycleLength }

    private var displayDay: Int? {
        hoverDay ?? cycleService.currentPhase?.cycleDay
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    if let phase = cycleService.currentPhase {
                        PhaseHeaderView(phase: phase)
                    }

                    Text("Hormones")
                        .font(.heading(32))
                        .foregroundStyle(.ink)

                    Text("Reference curves scaled to your \(totalDays)-day cycle.")
                        .font(.body(13))
                        .foregroundStyle(.muted)

                    // Legend toggles
                    legendRow

                    // Chart
                    HormoneChartView(
                        totalDays: totalDays,
                        visible: visible,
                        cycleDay: cycleService.currentPhase?.cycleDay,
                        phaseColor: cycleService.currentPhase.flatMap { Color(hex: phaseColorHex(for: $0.phaseSlug)) },
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
                        .font(.body(10))
                        .foregroundStyle(.muted.opacity(0.5))
                        .padding(.top, 8)
                }
                .padding()
            }
            .background(Color.paper)
        }
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
                                    .fill(visible[key] == true ? meta.color : Color.border)
                                    .frame(width: 8, height: 8)
                                Text(meta.fullName)
                                    .font(.bodyMedium(10))
                                    .textCase(.uppercase)
                                    .tracking(1.2)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(
                                        visible[key] == true ? meta.color.opacity(0.5) : Color.border,
                                        lineWidth: 1
                                    )
                            )
                            .foregroundStyle(visible[key] == true ? meta.color : .muted)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Day Detail Panel

    private func dayDetailPanel(day: Int) -> some View {
        let refDay = Int(round(Double(day - 1) / Double(totalDays - 1) * 27.0)) + 1

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Day \(day)")
                    .font(.bodyMedium(9))
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundStyle(.ink)
                Spacer()
                if let date = calendarDate(for: day) {
                    Text(date)
                        .font(.body(8))
                        .foregroundStyle(.muted.opacity(0.5))
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
                                    .font(.bodyMedium(10))
                                    .foregroundStyle(.ink)
                                Text(desc.label)
                                    .font(.body(9))
                                    .foregroundStyle(.muted)
                                Text(desc.range)
                                    .font(.body(8))
                                    .foregroundStyle(.muted.opacity(0.6))
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .overlay(Rectangle().stroke(Color.border, lineWidth: 1))
    }

    // MARK: - Hormone Cards

    private func hormoneCard(key: HormoneKey, meta: HormoneMeta) -> some View {
        VStack(spacing: 0) {
            Button {
                if expandedCards.contains(key) {
                    expandedCards.remove(key)
                } else {
                    expandedCards.insert(key)
                }
            } label: {
                HStack {
                    Circle()
                        .fill(meta.color)
                        .frame(width: 10, height: 10)
                    Text(meta.fullName)
                        .font(.bodyMedium(11))
                        .foregroundStyle(.ink)
                    Text(meta.unit)
                        .font(.body(9))
                        .foregroundStyle(.muted)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(.muted)
                        .rotationEffect(expandedCards.contains(key) ? .degrees(180) : .zero)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if expandedCards.contains(key) {
                Divider()
                    .padding(.horizontal, 16)
                VStack(alignment: .leading, spacing: 6) {
                    Text(meta.description)
                        .font(.body(12))
                        .foregroundStyle(.ink)
                    Text(meta.feel)
                        .font(.body(11))
                        .italic()
                        .foregroundStyle(.muted)
                    Text(meta.peakLabel)
                        .font(.bodyMedium(9))
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundStyle(.muted.opacity(0.6))
                        .padding(.top, 4)
                }
                .padding(16)
            }
        }
        .background(Color.white)
        .overlay(Rectangle().stroke(Color.border, lineWidth: 1))
    }

    // MARK: - Helpers

    private func calendarDate(for day: Int) -> String? {
        guard let startDate = cycleService.currentPhase?.periodStartDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let start = formatter.date(from: startDate) else { return nil }
        guard let date = Calendar.current.date(byAdding: .day, value: day - 1, to: start) else { return nil }
        let display = DateFormatter()
        display.dateFormat = "M/d"
        return display.string(from: date)
    }

    private func phaseColorHex(for slug: String) -> UInt {
        switch slug {
        case "menstrual":  return 0xB85252
        case "follicular": return 0x4A8C6A
        case "ovulatory":  return 0xC49A3C
        case "luteal":     return 0x7A5C9C
        default: return 0x9A8A7A
        }
    }
}
