import SwiftUI

// MARK: - Colors

extension Color {
    static let ink = Color(hex: 0x1C1712)
    static let paper = Color(hex: 0xF9F5EF)
    static let warm = Color(hex: 0xF2EBE0)
    static let warmer = Color(hex: 0xE8DDD0)
    static let spice = Color(hex: 0xC4693A)
    static let spiceSoft = Color(hex: 0xFAF0EB)
    static let muted = Color(hex: 0x9A8A7A)

    // Phase colors
    static let phaseM = Color(hex: 0xB85252)
    static let phaseMSoft = Color(hex: 0xF9EDED)
    static let phaseMMid = Color(hex: 0xDFB0B0)

    static let phaseF = Color(hex: 0x4A8C6A)
    static let phaseFSoft = Color(hex: 0xEAF3EE)
    static let phaseFMid = Color(hex: 0xA8CFBA)

    static let phaseO = Color(hex: 0xC49A3C)
    static let phaseOSoft = Color(hex: 0xFBF6E8)
    static let phaseOMid = Color(hex: 0xE2CC8A)

    static let phaseL = Color(hex: 0x7A5C9C)
    static let phaseLSoft = Color(hex: 0xF3EFF8)
    static let phaseLMid = Color(hex: 0xC4AADC)

    // Macro colors
    static let macroProtein = Color(hex: 0xB85252)
    static let macroCarbs = Color(hex: 0x8A6200)
    static let macroFat = Color(hex: 0x4A8C6A)

    // Border
    static let border = Color.ink.opacity(0.10)
    static let borderStrong = Color.ink.opacity(0.18)

    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

// ShapeStyle extensions for foregroundStyle compatibility
extension ShapeStyle where Self == Color {
    static var ink: Color { Color.ink }
    static var paper: Color { Color.paper }
    static var warm: Color { Color.warm }
    static var warmer: Color { Color.warmer }
    static var spice: Color { Color.spice }
    static var spiceSoft: Color { Color.spiceSoft }
    static var muted: Color { Color.muted }
    static var phaseM: Color { Color.phaseM }
    static var phaseMSoft: Color { Color.phaseMSoft }
    static var phaseMMid: Color { Color.phaseMMid }
    static var phaseF: Color { Color.phaseF }
    static var phaseFSoft: Color { Color.phaseFSoft }
    static var phaseFMid: Color { Color.phaseFMid }
    static var phaseO: Color { Color.phaseO }
    static var phaseOSoft: Color { Color.phaseOSoft }
    static var phaseOMid: Color { Color.phaseOMid }
    static var phaseL: Color { Color.phaseL }
    static var phaseLSoft: Color { Color.phaseLSoft }
    static var phaseLMid: Color { Color.phaseLMid }
    static var macroProtein: Color { Color.macroProtein }
    static var macroCarbs: Color { Color.macroCarbs }
    static var macroFat: Color { Color.macroFat }
}

// MARK: - Phase Color Lookup

struct PhaseColors {
    let color: Color
    let soft: Color
    let mid: Color

    static func forSlug(_ slug: String) -> PhaseColors {
        switch slug {
        case "menstrual":  return PhaseColors(color: .phaseM, soft: .phaseMSoft, mid: .phaseMMid)
        case "follicular": return PhaseColors(color: .phaseF, soft: .phaseFSoft, mid: .phaseFMid)
        case "ovulatory":  return PhaseColors(color: .phaseO, soft: .phaseOSoft, mid: .phaseOMid)
        case "luteal":     return PhaseColors(color: .phaseL, soft: .phaseLSoft, mid: .phaseLMid)
        default:           return PhaseColors(color: .muted, soft: .warm, mid: .warmer)
        }
    }
}

// MARK: - Typography

extension Font {
    static func heading(_ size: CGFloat) -> Font {
        .custom("CormorantGaramond-Light", size: size)
    }

    static func headingMedium(_ size: CGFloat) -> Font {
        .custom("CormorantGaramond-Medium", size: size)
    }

    static func body(_ size: CGFloat) -> Font {
        .custom("DMSans-Regular", size: size)
    }

    static func bodyLight(_ size: CGFloat) -> Font {
        .custom("DMSans-Light", size: size)
    }

    static func bodyMedium(_ size: CGFloat) -> Font {
        .custom("DMSans-Medium", size: size)
    }

    static let label = Font.custom("DMSans-Medium", size: 9)
}

// MARK: - View Modifiers

struct NamahLabelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.bodyMedium(9))
            .textCase(.uppercase)
            .tracking(2.5)
            .foregroundStyle(Color.muted)
    }
}

struct NamahButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.bodyMedium(10))
            .textCase(.uppercase)
            .tracking(2)
            .foregroundStyle(Color.paper)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.ink)
    }
}

extension View {
    func namahLabel() -> some View { modifier(NamahLabelStyle()) }
    func namahButton() -> some View { modifier(NamahButtonStyle()) }
}
