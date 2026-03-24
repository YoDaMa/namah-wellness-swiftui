import SwiftUI

/// SF Symbol icon lookup for nutrients and phase reminders.
/// Uses SF Symbols instead of emoji because iOS 26 simulator has a known bug
/// where Apple Color Emoji fails to render (shows [?] boxes).
/// Icons are resolved locally by keyword matching.
enum NamahIcons {

    /// Returns an SF Symbol name for a nutrient label.
    static func forNutrient(_ label: String) -> String {
        let lower = label.lowercased()
        for (keyword, symbol) in nutrientMap {
            if lower.contains(keyword) { return symbol }
        }
        return "leaf.fill"
    }

    /// Returns an SF Symbol name for a phase reminder.
    static func forReminder(_ text: String) -> String {
        let lower = text.lowercased()
        for (keyword, symbol) in reminderMap {
            if lower.contains(keyword) { return symbol }
        }
        return "sparkles"
    }

    // MARK: - Nutrient Keywords

    private static let nutrientMap: [(String, String)] = [
        ("iron", "drop.fill"),
        ("omega", "fish.fill"),
        ("salmon", "fish.fill"),
        ("turmeric", "leaf.fill"),
        ("ginger", "leaf.fill"),
        ("magnesium", "bolt.heart.fill"),
        ("vitamin c", "sun.max.fill"),
        ("flaxseed", "seedling"),
        ("fermented", "leaf.arrow.circlepath"),
        ("antioxidant", "shield.fill"),
        ("cruciferous", "leaf.fill"),
        ("lean protein", "flame.fill"),
        ("protein", "flame.fill"),
        ("zinc", "star.fill"),
        ("fiber", "leaf.fill"),
        ("vitamin b", "bolt.fill"),
        ("b6", "bolt.fill"),
        ("healthy fat", "drop.halffull"),
        ("complex carb", "chart.bar.fill"),
        ("tryptophan", "flame.fill"),
        ("turkey", "flame.fill"),
        ("caffeine", "cup.and.saucer.fill"),
        ("calcium", "cross.fill"),
        ("limit", "exclamationmark.triangle.fill"),
    ]

    // MARK: - Reminder Keywords

    private static let reminderMap: [(String, String)] = [
        ("estradiol", "bolt.fill"),
        ("iron", "drop.fill"),
        ("blood", "drop.fill"),
        ("period", "drop.fill"),
        ("menstrual", "drop.fill"),
        ("anti-inflammatory", "fish.fill"),
        ("omega", "fish.fill"),
        ("salmon", "fish.fill"),
        ("magnesium", "bolt.heart.fill"),
        ("supplement", "pills.fill"),
        ("yoga", "figure.mind.and.body"),
        ("stretch", "figure.mind.and.body"),
        ("gentle", "figure.mind.and.body"),
        ("walk", "figure.walk"),
        ("exercise", "figure.run"),
        ("workout", "dumbbell.fill"),
        ("train", "dumbbell.fill"),
        ("strength", "dumbbell.fill"),
        ("sleep", "moon.zzz.fill"),
        ("rest", "moon.zzz.fill"),
        ("temperature", "thermometer.medium"),
        ("bbt", "thermometer.medium"),
        ("hydrat", "drop.fill"),
        ("water", "drop.fill"),
        ("energy", "bolt.fill"),
        ("insulin", "syringe.fill"),
        ("fermented", "leaf.arrow.circlepath"),
        ("seed cycling", "seedling"),
        ("seed", "seedling"),
        ("flaxseed", "seedling"),
        ("salt", "exclamationmark.triangle.fill"),
        ("sodium", "exclamationmark.triangle.fill"),
        ("sugar", "exclamationmark.triangle.fill"),
        ("chocolate", "cup.and.saucer.fill"),
        ("caffeine", "cup.and.saucer.fill"),
        ("alcohol", "xmark.circle.fill"),
        ("bloat", "wind"),
        ("cramp", "bandage.fill"),
        ("mood", "face.smiling.fill"),
        ("serotonin", "face.smiling.fill"),
        ("feel", "hand.thumbsup.fill"),
        ("progesterone", "waveform.path.ecg"),
        ("estrogen", "waveform.path.ecg"),
        ("hormone", "waveform.path.ecg"),
        ("libido", "heart.fill"),
        ("ovulat", "sparkle"),
        ("fertile", "sparkle"),
        ("food", "fork.knife"),
        ("meal", "fork.knife"),
        ("cook", "fork.knife"),
        ("nutrient", "leaf.fill"),
        ("carbohydrate", "chart.bar.fill"),
        ("performance", "hand.thumbsup.fill"),
    ]
}

/// Renders an SF Symbol icon for use alongside text in insight rows and nutrient pills.
struct NamahIcon: View {
    let symbolName: String
    let size: CGFloat
    var color: Color = .accentColor

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: size))
            .symbolRenderingMode(.multicolor)
            .foregroundStyle(color)
    }
}
