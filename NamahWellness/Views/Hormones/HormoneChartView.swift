import SwiftUI

struct HormoneChartView: View {
    let totalDays: Int
    let visible: [HormoneKey: Bool]
    let cycleDay: Int?
    let phaseColor: Color?
    let phaseRanges: PhaseRanges
    @Binding var hoverDay: Int?

    private let chartWidth: CGFloat = 700
    private let chartHeight: CGFloat = 220
    private let pad = (top: CGFloat(18), right: CGFloat(16), bottom: CGFloat(38), left: CGFloat(10))

    private var cW: CGFloat { chartWidth - pad.left - pad.right }
    private var cH: CGFloat { chartHeight - pad.top - pad.bottom }

    private func dayToX(_ day: Int) -> CGFloat {
        let divisor = max(totalDays - 1, 1)
        return pad.left + CGFloat(day - 1) / CGFloat(divisor) * cW
    }

    private func valToY(_ v: Double) -> CGFloat {
        pad.top + CGFloat(1 - v) * cH
    }

    var body: some View {
        Canvas { context, size in
            let scaleX = size.width / chartWidth
            let scaleY = size.height / chartHeight

            // Phase bands
            let bands: [(String, PhaseRange, Color)] = [
                ("MENSTRUAL", phaseRanges.menstrual, Color.phaseMSoft),
                ("FOLLICULAR", phaseRanges.follicular, Color.phaseFSoft),
                ("OVULATORY", phaseRanges.ovulatory, Color.phaseOSoft),
                ("LUTEAL", phaseRanges.luteal, Color.phaseLSoft),
            ]

            for (_, range, color) in bands {
                let x = dayToX(range.start) * scaleX
                let w = (dayToX(range.end + 1) - dayToX(range.start)) * scaleX
                let rect = CGRect(x: x, y: pad.top * scaleY, width: w, height: cH * scaleY)
                context.fill(Path(rect), with: .color(color.opacity(0.7)))
            }

            // Grid lines
            for v in [0.25, 0.5, 0.75] {
                let y = valToY(v) * scaleY
                var path = Path()
                path.move(to: CGPoint(x: pad.left * scaleX, y: y))
                path.addLine(to: CGPoint(x: (chartWidth - pad.right) * scaleX, y: y))
                context.stroke(path, with: .color(.secondary.opacity(0.15)), lineWidth: 1)
            }

            // Hormone curves
            for key in HormoneKey.allCases {
                guard visible[key] == true, let curve = HormoneData.curves[key], let meta = HormoneData.meta[key] else { continue }

                var path = Path()
                for i in 1...totalDays {
                    let val = HormoneData.interpolateCurve(curve, day: i, totalDays: totalDays)
                    let pt = CGPoint(x: dayToX(i) * scaleX, y: valToY(val) * scaleY)
                    if i == 1 { path.move(to: pt) } else { path.addLine(to: pt) }
                }
                context.stroke(path, with: .color(meta.color.opacity(hoverDay != nil ? 0.5 : 0.9)), lineWidth: 1.8)

                // Bold segment up to current day
                if let cd = cycleDay, cd <= totalDays, cd >= 2 {
                    var boldPath = Path()
                    for i in 1...cd {
                        let val = HormoneData.interpolateCurve(curve, day: i, totalDays: totalDays)
                        let pt = CGPoint(x: dayToX(i) * scaleX, y: valToY(val) * scaleY)
                        if i == 1 { boldPath.move(to: pt) } else { boldPath.addLine(to: pt) }
                    }
                    context.stroke(boldPath, with: .color(meta.color), lineWidth: 2.2)
                }
            }

            // Current day marker
            if let cd = cycleDay, cd <= totalDays {
                let x = dayToX(cd) * scaleX
                var line = Path()
                line.move(to: CGPoint(x: x, y: pad.top * scaleY))
                line.addLine(to: CGPoint(x: x, y: (pad.top + cH) * scaleY))
                context.stroke(line, with: .color((phaseColor ?? .spice).opacity(0.8)),
                              style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))

                let dot = CGRect(x: x - 3, y: (pad.top - 5) * scaleY - 3, width: 6, height: 6)
                context.fill(Path(ellipseIn: dot), with: .color(phaseColor ?? .spice))
            }

            // Hover crosshair
            if let hd = hoverDay {
                let x = dayToX(hd) * scaleX
                var line = Path()
                line.move(to: CGPoint(x: x, y: pad.top * scaleY))
                line.addLine(to: CGPoint(x: x, y: (pad.top + cH) * scaleY))
                context.stroke(line, with: .color(.secondary.opacity(0.4)), lineWidth: 1)

                for key in HormoneKey.allCases {
                    guard visible[key] == true, let curve = HormoneData.curves[key], let meta = HormoneData.meta[key] else { continue }
                    let val = HormoneData.interpolateCurve(curve, day: hd, totalDays: totalDays)
                    let pt = CGPoint(x: x, y: valToY(val) * scaleY)
                    let dotRect = CGRect(x: pt.x - 4, y: pt.y - 4, width: 8, height: 8)
                    context.fill(Path(ellipseIn: dotRect), with: .color(meta.color))
                    context.stroke(Path(ellipseIn: dotRect), with: .color(Color(uiColor: .secondarySystemGroupedBackground)), lineWidth: 1.5)
                }
            }
        }
        .frame(height: 180)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let fraction = value.location.x / UIScreen.main.bounds.width
                    let day = Int(round(fraction * CGFloat(max(totalDays - 1, 1)))) + 1
                    hoverDay = max(1, min(totalDays, day))
                }
                .onEnded { _ in hoverDay = nil }
        )
    }
}
