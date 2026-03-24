import Foundation

/// Emoji icon lookup for nutrients and phase reminders.
/// Hardcoded as Swift string literals (guaranteed to render).
/// The database emoji field gets corrupted through the sync pipeline,
/// so we resolve emojis locally by keyword matching.
enum NamahIcons {

    /// Returns an emoji for a nutrient label.
    static func forNutrient(_ label: String) -> String {
        let lower = label.lowercased()
        for (keyword, emoji) in nutrientMap {
            if lower.contains(keyword) { return emoji }
        }
        return "🌿"
    }

    /// Returns an emoji for a phase reminder.
    static func forReminder(_ text: String) -> String {
        let lower = text.lowercased()
        for (keyword, emoji) in reminderMap {
            if lower.contains(keyword) { return emoji }
        }
        return "✨"
    }

    // MARK: - Nutrient Keywords

    private static let nutrientMap: [(String, String)] = [
        ("iron", "🔴"),
        ("omega", "🐟"),
        ("salmon", "🐟"),
        ("turmeric", "🌿"),
        ("ginger", "🌿"),
        ("magnesium", "🍫"),
        ("vitamin c", "🍋"),
        ("flaxseed", "🌾"),
        ("fermented", "🥬"),
        ("antioxidant", "🍇"),
        ("cruciferous", "🥦"),
        ("lean protein", "🍗"),
        ("protein", "🍗"),
        ("zinc", "🌻"),
        ("fiber", "🥦"),
        ("vitamin b", "🍌"),
        ("b6", "🍌"),
        ("healthy fat", "🥑"),
        ("complex carb", "🍠"),
        ("tryptophan", "🍗"),
        ("turkey", "🍗"),
        ("caffeine", "☕"),
        ("calcium", "🥛"),
        ("limit", "⚠️"),
    ]

    // MARK: - Reminder Keywords

    private static let reminderMap: [(String, String)] = [
        ("estradiol", "⚡"),
        ("iron", "🩸"),
        ("blood", "🩸"),
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
        ("seed", "🌱"),
        ("flaxseed", "🌱"),
        ("salt", "⚠️"),
        ("sodium", "⚠️"),
        ("sugar", "⚠️"),
        ("chocolate", "🍫"),
        ("caffeine", "☕"),
        ("alcohol", "🚫"),
        ("bloat", "💨"),
        ("cramp", "🩹"),
        ("mood", "😊"),
        ("serotonin", "😊"),
        ("feel", "💪"),
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
        ("carbohydrate", "🍞"),
        ("performance", "💪"),
    ]
}
