import SwiftUI

// MARK: - Brand Colors (Phase accents — these are brand identity, not text/background)

extension Color {
    // Phase colors
    static let phaseM = Color(hex: 0xB85252)
    static let phaseMSoft = Color(adaptive: (light: 0xF9EDED, dark: 0x3A2222))
    static let phaseMMid = Color(adaptive: (light: 0xDFB0B0, dark: 0x6B3838))

    static let phaseF = Color(hex: 0x4A8C6A)
    static let phaseFSoft = Color(adaptive: (light: 0xEAF3EE, dark: 0x1E2E24))
    static let phaseFMid = Color(adaptive: (light: 0xA8CFBA, dark: 0x305540))

    static let phaseO = Color(hex: 0xC49A3C)
    static let phaseOSoft = Color(adaptive: (light: 0xFBF6E8, dark: 0x2E2618))
    static let phaseOMid = Color(adaptive: (light: 0xE2CC8A, dark: 0x5C4A22))

    static let phaseL = Color(hex: 0x7A5C9C)
    static let phaseLSoft = Color(adaptive: (light: 0xF3EFF8, dark: 0x2A2236))
    static let phaseLMid = Color(adaptive: (light: 0xC4AADC, dark: 0x453660))

    // Macro colors
    static let macroProtein = Color(hex: 0xB85252)
    static let macroCarbs = Color(adaptive: (light: 0x8A6200, dark: 0xC49A3C))
    static let macroFat = Color(hex: 0x4A8C6A)

    // Brand accent
    static let spice = Color(hex: 0xC4693A)

    // Warm cream for callouts — adapts to dark mode
    static let saCalloutBackground = Color(adaptive: (light: 0xFFF8F0, dark: 0x2D2520))

    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }

    /// Creates a color that adapts between light and dark mode.
    init(adaptive pair: (light: UInt, dark: UInt)) {
        self.init(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? pair.dark : pair.light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255.0,
                green: CGFloat((hex >> 8) & 0xFF) / 255.0,
                blue: CGFloat(hex & 0xFF) / 255.0,
                alpha: 1.0
            )
        })
    }
}

// ShapeStyle extensions for foregroundStyle compatibility
extension ShapeStyle where Self == Color {
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
    static var spice: Color { Color.spice }
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
        default:           return PhaseColors(color: .secondary, soft: Color(uiColor: .tertiarySystemFill), mid: Color(uiColor: .secondarySystemFill))
        }
    }
}

// MARK: - Typography

extension Font {
    // ── Display Serif (DM Serif Display) ──
    // Page titles, section headers, modal titles — orienting text
    static func display(_ size: CGFloat, relativeTo style: TextStyle = .title) -> Font {
        .custom("ETBookOT-Roman", size: size, relativeTo: style)
    }

    static func displayItalic(_ size: CGFloat, relativeTo style: TextStyle = .title) -> Font {
        .custom("ETBookOT-Italic", size: size, relativeTo: style)
    }

    // ── Prose (ET Book) ──
    // Educational / interpretive text the user reads and sits with
    static func prose(_ size: CGFloat, relativeTo style: TextStyle = .body) -> Font {
        .custom("ETBookOT-Roman", size: size, relativeTo: style)
    }

    static func proseBold(_ size: CGFloat, relativeTo style: TextStyle = .body) -> Font {
        .custom("ETBookOT-Bold", size: size, relativeTo: style)
    }

    static func proseItalic(_ size: CGFloat, relativeTo style: TextStyle = .body) -> Font {
        .custom("ETBookOT-Italic", size: size, relativeTo: style)
    }

    // ── Sans (Plus Jakarta Sans) ──
    // Everything else: data labels, stats, buttons, nav, form fields
    static func sans(_ size: CGFloat, relativeTo style: TextStyle = .body) -> Font {
        .custom("Plus Jakarta Sans", size: size, relativeTo: style)
    }

    // Named text-style equivalents (Plus Jakarta Sans)
    static var nTitle: Font  { .sans(28, relativeTo: .title) }
    static var nHeadline: Font { .sans(17, relativeTo: .headline) }
    static var nSubheadline: Font { .sans(15, relativeTo: .subheadline) }
    static var nFootnote: Font { .sans(13, relativeTo: .footnote) }
    static var nCaption: Font  { .sans(12, relativeTo: .caption) }
    static var nCaption2: Font { .sans(11, relativeTo: .caption2) }
}

// MARK: - Label Style (editorial brand element)

struct NamahLabelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.nCaption2)
            .fontWeight(.medium)
            .textCase(.uppercase)
            .tracking(2)
            .foregroundStyle(.secondary)
    }
}

extension View {
    func namahLabel() -> some View { modifier(NamahLabelStyle()) }
}
