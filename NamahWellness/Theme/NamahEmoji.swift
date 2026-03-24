import Foundation

/// SF Symbol icon lookup for nutrients and phase reminders.
/// Maps label keywords to SF Symbol names for reliable rendering.
enum NamahIcons {

    /// Returns an SF Symbol name for a nutrient label.
    static func forNutrient(_ label: String) -> String {
        let lower = label.lowercased()
        for (keyword, symbol) in nutrientMap {
            if lower.contains(keyword) { return symbol }
        }
        return "leaf"
    }

    /// Returns an SF Symbol name for a phase reminder.
    static func forReminder(_ text: String) -> String {
        let lower = text.lowercased()
        for (keyword, symbol) in reminderMap {
            if lower.contains(keyword) { return symbol }
        }
        return "sparkles"
    }

    // MARK: - Nutrient Keywords → SF Symbols

    private static let nutrientMap: [(String, String)] = [
        ("iron", "drop.fill"),
        ("omega", "fish.fill"),
        ("salmon", "fish.fill"),
        ("turmeric", "leaf.fill"),
        ("ginger", "leaf.fill"),
        ("magnesium", "bolt.fill"),
        ("vitamin c", "sun.max.fill"),
        ("flaxseed", "seedling"),
        ("fermented", "bubbles.and.sparkles"),
        ("antioxidant", "shield.checkered"),
        ("cruciferous", "leaf.arrow.circlepath"),
        ("lean protein", "figure.strengthtraining.traditional"),
        ("protein", "figure.strengthtraining.traditional"),
        ("zinc", "staroflife.fill"),
        ("fiber", "circle.grid.3x3.fill"),
        ("vitamin b", "pill.fill"),
        ("b6", "pill.fill"),
        ("healthy fat", "drop.triangle"),
        ("complex carb", "wheat.bundle.fill"),
        ("tryptophan", "moon.zzz.fill"),
        ("turkey", "moon.zzz.fill"),
        ("caffeine", "cup.and.saucer.fill"),
        ("calcium", "bone"),
    ]

    // MARK: - Reminder Keywords → SF Symbols

    private static let reminderMap: [(String, String)] = [
        ("estradiol", "bolt.fill"),
        ("iron", "drop.fill"),
        ("blood", "drop.fill"),
        ("period", "drop.fill"),
        ("menstrual", "drop.fill"),
        ("anti-inflammatory", "fish.fill"),
        ("omega", "fish.fill"),
        ("salmon", "fish.fill"),
        ("magnesium", "bolt.fill"),
        ("supplement", "pill.fill"),
        ("yoga", "figure.yoga"),
        ("stretch", "figure.flexibility"),
        ("gentle", "figure.flexibility"),
        ("walk", "figure.walk"),
        ("exercise", "figure.run"),
        ("workout", "figure.strengthtraining.traditional"),
        ("train", "figure.strengthtraining.traditional"),
        ("strength", "dumbbell.fill"),
        ("sleep", "moon.zzz.fill"),
        ("rest", "moon.zzz.fill"),
        ("temperature", "thermometer.medium"),
        ("bbt", "thermometer.medium"),
        ("hydrat", "drop.fill"),
        ("water", "drop.fill"),
        ("energy", "bolt.fill"),
        ("insulin", "syringe.fill"),
        ("fermented", "bubbles.and.sparkles"),
        ("seed cycling", "seedling"),
        ("flaxseed", "seedling"),
        ("salt", "exclamationmark.triangle"),
        ("sodium", "exclamationmark.triangle"),
        ("sugar", "exclamationmark.triangle"),
        ("chocolate", "heart.fill"),
        ("caffeine", "cup.and.saucer.fill"),
        ("alcohol", "xmark.circle"),
        ("bloat", "wind"),
        ("cramp", "waveform.path"),
        ("mood", "face.smiling"),
        ("serotonin", "face.smiling"),
        ("progesterone", "waveform.path.ecg"),
        ("estrogen", "waveform.path.ecg"),
        ("hormone", "waveform.path.ecg"),
        ("libido", "heart.fill"),
        ("ovulat", "sparkles"),
        ("fertile", "sparkles"),
        ("food", "fork.knife"),
        ("meal", "fork.knife"),
        ("cook", "fork.knife"),
        ("nutrient", "leaf.fill"),
    ]
}
