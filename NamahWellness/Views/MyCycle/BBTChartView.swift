import SwiftUI
import Charts
import SwiftData

struct BBTChartView: View {
    let bbtLogs: [BBTLog]
    let cycleLogs: [CycleLog]
    let cycleStats: CycleStats
    let phaseRanges: PhaseRanges

    private var sortedLogs: [BBTLog] {
        bbtLogs.sorted { $0.date < $1.date }
    }

    private var displayUnit: TemperatureUnit {
        bbtLogs.last?.unit ?? .fahrenheit
    }

    /// Last 30 days of data for charting
    private var chartData: [ChartPoint] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current

        return sortedLogs.suffix(30).compactMap { log in
            guard let date = formatter.date(from: log.date) else { return nil }
            let temp = displayUnit == .fahrenheit
                ? log.temperatureInFahrenheit
                : displayUnit.fromFahrenheit(log.temperatureInFahrenheit)
            return ChartPoint(date: date, temperature: temp, dateString: log.date)
        }
    }

    /// Coverline = average of 6 lowest pre-ovulation temps
    private var coverline: Double? {
        let temps = chartData.map(\.temperature).sorted()
        guard temps.count >= 6 else { return nil }
        let lowest6 = temps.prefix(6)
        return lowest6.reduce(0, +) / Double(lowest6.count)
    }

    /// Phase background bands for the chart
    private var phaseBands: [PhaseBand] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current

        guard let firstDate = chartData.first?.date,
              let lastDate = chartData.last?.date else { return [] }

        var bands: [PhaseBand] = []
        var currentDate = firstDate
        let calendar = Calendar.current

        while currentDate <= lastDate {
            let dateStr = formatter.string(from: currentDate)
            let phaseInfo = CalendarService.getPhaseForDate(
                dateStr, logs: cycleLogs,
                stats: cycleStats, phaseRanges: phaseRanges
            )

            if let phase = phaseInfo {
                let slug = phase.phaseSlug
                if let last = bands.last, last.phaseSlug == slug {
                    bands[bands.count - 1].endDate = currentDate
                } else {
                    bands.append(PhaseBand(
                        phaseSlug: slug,
                        startDate: currentDate,
                        endDate: currentDate
                    ))
                }
            }

            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate.addingTimeInterval(86400)
        }

        return bands
    }

    private var tempRange: ClosedRange<Double> {
        let temps = chartData.map(\.temperature)
        guard let min = temps.min(), let max = temps.max() else {
            return displayUnit == .fahrenheit ? 97.0...99.0 : 36.0...37.5
        }
        let padding = (max - min) * 0.2
        return (min - padding)...(max + padding)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("BBT TREND")
                    .namahLabel()
                Spacer()
                Text("\(chartData.count) of 30 days logged")
                    .font(.nCaption2)
                    .foregroundStyle(.tertiary)
            }

            if chartData.count < 3 {
                emptyChartState
            } else {
                chart
                    .frame(height: 180)

                if let cl = coverline {
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(.secondary)
                            .frame(width: 16, height: 1)
                        Text("Coverline: \(String(format: "%.1f", cl))\(displayUnit.symbol)")
                            .font(.nCaption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Chart

    private var chart: some View {
        Chart {
            // Phase background bands
            ForEach(phaseBands, id: \.startDate) { band in
                RectangleMark(
                    xStart: .value("Start", band.startDate),
                    xEnd: .value("End", Calendar.current.date(byAdding: .day, value: 1, to: band.endDate) ?? band.endDate),
                    yStart: .value("Min", tempRange.lowerBound),
                    yEnd: .value("Max", tempRange.upperBound)
                )
                .foregroundStyle(colorForPhase(band.phaseSlug).opacity(0.12))
            }

            // Coverline
            if let cl = coverline {
                RuleMark(y: .value("Coverline", cl))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.secondary.opacity(0.5))
            }

            // Temperature line — connect consecutive days, gap otherwise
            ForEach(connectedSegments(), id: \.0) { segment in
                ForEach(segment.1, id: \.date) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Temp", point.temperature),
                        series: .value("Segment", segment.0)
                    )
                    .foregroundStyle(Color.primary.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
            }

            // Data points
            ForEach(chartData, id: \.date) { point in
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Temp", point.temperature)
                )
                .symbolSize(20)
                .foregroundStyle(Color.primary)
            }
        }
        .chartYScale(domain: tempRange)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let temp = value.as(Double.self) {
                        Text(String(format: "%.1f", temp))
                            .font(.system(size: 9))
                    }
                }
            }
        }
    }

    /// Split chart data into connected segments (gap > 2 days = new segment)
    private func connectedSegments() -> [(Int, [ChartPoint])] {
        guard !chartData.isEmpty else { return [] }

        var segments: [(Int, [ChartPoint])] = []
        var current: [ChartPoint] = [chartData[0]]
        var segmentId = 0

        for i in 1..<chartData.count {
            let prev = chartData[i - 1].date
            let curr = chartData[i].date
            let gap = Calendar.current.dateComponents([.day], from: prev, to: curr).day ?? 0

            if gap > 2 {
                segments.append((segmentId, current))
                segmentId += 1
                current = [chartData[i]]
            } else {
                current.append(chartData[i])
            }
        }
        segments.append((segmentId, current))
        return segments
    }

    private var emptyChartState: some View {
        VStack(spacing: 8) {
            Image(systemName: "thermometer.medium")
                .font(.title)
                .foregroundStyle(.tertiary)
            Text("Start logging BBT to see your temperature trend")
                .font(.nCaption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }

    private func colorForPhase(_ slug: String) -> Color {
        switch slug {
        case "menstrual": return .phaseM
        case "follicular": return .phaseF
        case "ovulatory": return .phaseO
        case "luteal": return .phaseL
        default: return .clear
        }
    }
}

// MARK: - Supporting Types

private struct ChartPoint {
    let date: Date
    let temperature: Double
    let dateString: String
}

private struct PhaseBand {
    let phaseSlug: String
    let startDate: Date
    var endDate: Date
}
