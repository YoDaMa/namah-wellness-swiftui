import Foundation

/// Hardcoded emoji lookup for nutrients and phase reminders.
/// The backend stores emoji icons but they can get corrupted through the
/// Turso → JSON → JSONDecoder → SwiftData pipeline. This lookup provides
/// a reliable local fallback keyed by label substring.
enum NamahEmoji {

    /// Returns an emoji for a nutrient label, or a generic leaf if no match.
    static func forNutrient(_ label: String) -> String {
        let lower = label.lowercased()
        for (keyword, emoji) in nutrientMap {
            if lower.contains(keyword) { return emoji }
        }
        return "🌿"
    }

    /// Returns an emoji for a phase reminder, or a generic sparkle if no match.
    static func forReminder(_ text: String) -> String {
        let lower = text.lowercased()
        for (keyword, emoji) in reminderMap {
            if lower.contains(keyword) { return emoji }
        }
        return "✨"
    }

    // MARK: - Nutrient Keywords → Emoji

    private static let nutrientMap: [(String, String)] = [
        // Menstrual
        ("iron", "🔴"),
        ("omega-3", "🐟"),
        ("omega‑3", "🐟"),
        ("salmon", "🐟"),
        ("turmeric", "🌿"),
        ("ginger", "🌿"),
        ("magnesium", "🍫"),
        ("vitamin c", "🍋"),
        // Follicular
        ("flaxseed", "🌾"),
        ("fermented", "🥬"),
        ("antioxidant", "🍇"),
        ("cruciferous", "🥦"),
        ("lean protein", "🍗"),
        ("protein", "🍗"),
        // Ovulatory
        ("zinc", "🌻"),
        ("fiber", "🥦"),
        ("vitamin b6", "🍌"),
        ("b6", "🍌"),
        ("healthy fat", "🥑"),
        // Luteal
        ("complex carb", "🍠"),
        ("tryptophan", "🍗"),
        ("turkey", "🍗"),
        ("caffeine", "☕"),
        ("calcium", "🥛"),
    ]

    // MARK: - Reminder Keywords → Emoji

    private static let reminderMap: [(String, String)] = [
        ("estradiol", "⚡"),
        ("iron", "🩸"),
        ("blood loss", "🩸"),
        ("period", "🩸"),
        ("menstrual", "🩸"),
        ("anti-inflammatory", "🐟"),
        ("omega", "🐟"),
        ("salmon", "🐟"),
        ("magnesium", "🍫"),
        ("supplement", "💊"),
        ("yoga", "🧘"),
        ("stretch", "🧘"),
        ("gentle", "🧘"),
        ("walk", "🚶"),
        ("exercise", "🏃"),
        ("workout", "🏋️"),
        ("train", "🏋️"),
        ("strength", "🏋️"),
        ("sleep", "😴"),
        ("rest", "😴"),
        ("temperature", "🌡️"),
        ("bbt", "🌡️"),
        ("hydrat", "💧"),
        ("water", "💧"),
        ("energy", "⚡"),
        ("insulin", "🧪"),
        ("fermented", "🫙"),
        ("seed cycling", "🌱"),
        ("flaxseed", "🌱"),
        ("salt", "🧂"),
        ("sodium", "🧂"),
        ("sugar", "🍬"),
        ("chocolate", "🍫"),
        ("caffeine", "☕"),
        ("alcohol", "🚫"),
        ("bloat", "💨"),
        ("cramp", "🩹"),
        ("mood", "😊"),
        ("serotonin", "😊"),
        ("progesterone", "🔬"),
        ("estrogen", "🔬"),
        ("hormone", "🔬"),
        ("libido", "💕"),
        ("ovulat", "🌸"),
        ("fertile", "🌸"),
        ("food", "🥗"),
        ("meal", "🍽️"),
        ("cook", "🍽️"),
        ("nutrient", "🥗"),
    ]
}
