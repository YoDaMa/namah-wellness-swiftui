import SwiftUI

// MARK: - Phase Signature Shapes
//
// Each phase has a unique geometric motif rendered as a SwiftUI Shape.
// Used as subtle overlays (10% opacity) inside the PhaseHeroCard.
//
//   Menstrual:  grounded horizontal wave — resting, earthbound
//   Follicular: ascending arc — energy building upward
//   Ovulatory:  peak/triangle — summit energy
//   Luteal:     plateau/gentle descent — winding down

/// Menstrual: a grounded, gently rolling wave along the bottom
struct MenstrualShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let h = rect.height * 0.35
        let y = rect.maxY - h
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: y + h * 0.3))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: y + h * 0.1),
            control: CGPoint(x: rect.width * 0.25, y: y - h * 0.1)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: y + h * 0.25),
            control: CGPoint(x: rect.width * 0.75, y: y + h * 0.3)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Follicular: an ascending arc from bottom-left to top-right — energy rising
struct FollicularShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let startY = rect.maxY
        let endY = rect.height * 0.4
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: startY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: endY),
            control: CGPoint(x: rect.width * 0.6, y: startY * 0.7)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Ovulatory: a peak/triangle shape — summit energy, confidence
struct OvulatoryShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let peakX = rect.width * 0.65
        let peakY = rect.height * 0.3
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.width * 0.2, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: peakX, y: peakY),
            control: CGPoint(x: rect.width * 0.45, y: rect.height * 0.55)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.height * 0.6),
            control: CGPoint(x: rect.width * 0.85, y: peakY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Luteal: a plateau with gentle descent — winding down
struct LutealShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let plateauY = rect.height * 0.45
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: plateauY))
        path.addLine(to: CGPoint(x: rect.width * 0.5, y: plateauY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.height * 0.75),
            control: CGPoint(x: rect.width * 0.8, y: plateauY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Phase Shape Lookup

extension PhaseColors {
    /// Returns the signature Shape view for a given phase slug, rendered as an overlay.
    @ViewBuilder
    static func shapeOverlay(for slug: String) -> some View {
        switch slug {
        case "menstrual":  MenstrualShape().fill(.white.opacity(0.10))
        case "follicular": FollicularShape().fill(.white.opacity(0.10))
        case "ovulatory":  OvulatoryShape().fill(.white.opacity(0.10))
        case "luteal":     LutealShape().fill(.white.opacity(0.10))
        default:           EmptyView()
        }
    }
}
