import SwiftUI

// MARK: - Types

enum HormoneKey: String, CaseIterable, Identifiable {
    case E2, P4, LH, FSH
    var id: String { rawValue }
}

struct HormoneDescriptor {
    let label: String
    let range: String
}

struct HormoneMeta {
    let name: String
    let fullName: String
    let color: Color
    let colorHex: String
    let unit: String
    let peakLabel: String
    let description: String
    let feel: String
    let ranges: [(days: ClosedRange<Int>, label: String, range: String)]
}

// MARK: - Static Data

enum HormoneData {
    // 28-point normalized curves (0.0–1.0). Index 0 = Day 1.
    static let curves: [HormoneKey: [Double]] = [
        .E2:  [0.08,0.07,0.06,0.07,0.08, 0.10,0.16,0.24,0.32,0.40, 0.56,0.78,0.98,0.95,0.70,
               0.46,0.40,0.44,0.50,0.56, 0.60,0.54,0.44,0.34,0.24, 0.16,0.11,0.08],
        .P4:  [0.02,0.02,0.02,0.02,0.02, 0.02,0.02,0.02,0.02,0.02, 0.02,0.02,0.02,0.06,0.14,
               0.28,0.48,0.66,0.82,0.92, 1.00,0.96,0.86,0.70,0.48, 0.28,0.12,0.04],
        .LH:  [0.07,0.07,0.07,0.07,0.07, 0.07,0.07,0.08,0.08,0.09, 0.10,0.16,0.34,1.00,0.90,
               0.36,0.12,0.08,0.07,0.06, 0.06,0.06,0.06,0.06,0.06, 0.06,0.07,0.07],
        .FSH: [0.82,1.00,0.94,0.82,0.70, 0.62,0.55,0.48,0.42,0.38, 0.32,0.30,0.42,0.60,0.36,
               0.26,0.22,0.22,0.20,0.20, 0.20,0.20,0.20,0.22,0.24, 0.28,0.34,0.44],
    ]

    static let meta: [HormoneKey: HormoneMeta] = [
        .E2: HormoneMeta(
            name: "E2", fullName: "Estradiol", color: .phaseM, colorHex: "#B85252", unit: "pg/mL",
            peakLabel: "Preovulatory peak ~200-500 pg/mL",
            description: "The mood and energy driver. Peaks before ovulation, drops at menstruation. Directly boosts serotonin, dopamine, and BDNF in the brain.",
            feel: "Rising estradiol = rising mood, motivation, and sociability. Falling estradiol (late luteal) = mood instability.",
            ranges: [
                (1...5, "Low baseline", "25-75 pg/mL"),
                (6...10, "Rising", "50-150 pg/mL"),
                (11...13, "Peak approaching", "150-350 pg/mL"),
                (13...14, "Preovulatory peak", "200-500 pg/mL"),
                (15...16, "Post-peak decline", "100-200 pg/mL"),
                (17...22, "Luteal rise", "100-250 pg/mL"),
                (23...28, "Declining", "250->40 pg/mL"),
            ]
        ),
        .P4: HormoneMeta(
            name: "P4", fullName: "Progesterone", color: .phaseL, colorHex: "#7A5C9C", unit: "ng/mL",
            peakLabel: "Mid-luteal peak ~10-25 ng/mL",
            description: "The luteal phase hormone. Rises after ovulation from the corpus luteum. Converts to allopregnanolone, which calms the nervous system — until it drops.",
            feel: "Early luteal: calm and sleepy. Late luteal withdrawal: mood instability, anxiety, irritability.",
            ranges: [
                (1...13, "Follicular baseline", "< 0.5 ng/mL"),
                (14...16, "Periovulatory rise", "1-3 ng/mL"),
                (17...19, "Rapid rise", "3-15 ng/mL"),
                (20...23, "Mid-luteal peak", "10-25 ng/mL"),
                (24...28, "Declining", "20->0.5 ng/mL"),
            ]
        ),
        .LH: HormoneMeta(
            name: "LH", fullName: "Luteinizing Hormone", color: .phaseO, colorHex: "#C49A3C", unit: "mIU/mL",
            peakLabel: "Ovulatory surge ~20-100 mIU/mL",
            description: "Triggers ovulation. The LH surge lasts ~48 hours and is the most dramatic hormonal event of the cycle.",
            feel: "The surge itself is not felt, but coincides with peak energy, libido, and the start of the temperature rise.",
            ranges: [
                (1...11, "Tonic baseline", "2-8 mIU/mL"),
                (12...13, "Pre-surge rise", "8-20 mIU/mL"),
                (13...14, "LH SURGE", "20-100 mIU/mL"),
                (15...16, "Rapid descent", "10->5 mIU/mL"),
                (17...28, "Luteal baseline", "1-5 mIU/mL"),
            ]
        ),
        .FSH: HormoneMeta(
            name: "FSH", fullName: "Follicle-Stimulating Hormone", color: .phaseF, colorHex: "#4A8C6A", unit: "mIU/mL",
            peakLabel: "Intercycle peak ~8-12 mIU/mL",
            description: "Recruits follicles at the start of each cycle. Declines as estradiol rises, then a small surge accompanies LH at ovulation.",
            feel: "Not directly felt. High FSH in early cycle means your next cycle is beginning.",
            ranges: [
                (1...3, "Intercycle peak", "5-12 mIU/mL"),
                (4...11, "Declining", "10->3 mIU/mL"),
                (12...12, "Nadir", "3-5 mIU/mL"),
                (13...14, "Ovulatory mini-surge", "4-15 mIU/mL"),
                (15...28, "Luteal suppression", "1.5-4 mIU/mL"),
            ]
        ),
    ]

    // MARK: - Functions

    /// Interpolate a 28-point normalized curve to get the value at any day of a variable-length cycle
    static func interpolateCurve(_ curve: [Double], day: Int, totalDays: Int) -> Double {
        let index = Double(day - 1) / Double(totalDays - 1) * 27.0
        let lo = Int(floor(index))
        let hi = min(lo + 1, 27)
        let frac = index - Double(lo)
        return curve[lo] * (1 - frac) + curve[hi] * frac
    }

    /// Get descriptor for a hormone at a given day (on a standard 28-day scale)
    static func getDescriptor(key: HormoneKey, day: Int) -> HormoneDescriptor {
        guard let m = meta[key] else { return HormoneDescriptor(label: "—", range: "—") }
        if let match = m.ranges.last(where: { day >= $0.days.lowerBound && day <= $0.days.upperBound }) {
            return HormoneDescriptor(label: match.label, range: match.range)
        }
        return HormoneDescriptor(label: "—", range: "—")
    }
}
