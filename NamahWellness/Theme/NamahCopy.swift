import Foundation

/// Centralized motivational copy for the app.
/// All user-facing greeting text, phase one-liners, and motivational strings
/// live here so they can be audited, updated, and eventually localized in one place.
enum NamahCopy {

    // MARK: - Greeting

    /// Returns a time-appropriate greeting and phase-aware subtitle.
    /// Selection is deterministic per calendar day (seeded by date) to avoid
    /// random text flickering on SwiftUI body re-evaluation.
    static func greeting(phase: String?, hour: Int) -> (title: String, subtitle: String?) {
        let timeGreeting: String
        switch hour {
        case 0..<12:  timeGreeting = "Good morning"
        case 12..<17: timeGreeting = "Good afternoon"
        default:      timeGreeting = "Good evening"
        }

        guard let phase else {
            return (timeGreeting, nil)
        }

        let subtitles = phaseSubtitles(for: phase, hour: hour)
        let subtitle = stableChoice(from: subtitles)
        return (timeGreeting, subtitle)
    }

    // MARK: - Phase One-Liners

    /// Returns a motivational one-liner for the current phase.
    static func phaseOneLiner(_ slug: String) -> String? {
        let options: [String]
        switch slug {
        case "menstrual":
            options = [
                "Rest is productive today — honor your body's need to slow down.",
                "Your body is doing important work. Give it space.",
                "Slow mornings, warm meals, early nights. That's the plan.",
                "This is your reset. Everything rebuilds from here."
            ]
        case "follicular":
            options = [
                "Your energy is building — great day for trying something new.",
                "Fresh cycle energy. Your body is ready to move and create.",
                "Rising estrogen, rising ambition. Lean into it.",
                "This is your launchpad phase. Start something."
            ]
        case "ovulatory":
            options = [
                "Peak energy and confidence — make the most of it.",
                "You're at your most magnetic. Show up fully today.",
                "Peak fertility, peak power. Your body is firing on all cylinders.",
                "Everything peaks now — energy, mood, communication. Use it."
            ]
        case "luteal":
            options = [
                "Winding down — focus on comfort foods and gentle movement.",
                "Your body is shifting inward. Cozy meals, shorter workouts.",
                "Progesterone is rising. Warm, grounding choices today.",
                "Nesting energy. Honor the slow-down."
            ]
        default:
            return nil
        }
        return stableChoice(from: options)
    }

    // MARK: - Private Helpers

    /// Picks a stable element from an array, seeded by the current calendar day.
    /// Same day always returns the same index, avoiding re-render flicker.
    private static func stableChoice(from options: [String]) -> String? {
        guard !options.isEmpty else { return nil }
        let calendar = Calendar.current
        let day = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return options[day % options.count]
    }

    private static func phaseSubtitles(for phase: String, hour: Int) -> [String] {
        let isMorning = hour < 12
        let isEvening = hour >= 17

        switch phase {
        case "menstrual":
            if isMorning {
                return [
                    "Ease into it. Your body is resetting.",
                    "A gentle morning sets the tone. No rush.",
                    "Start slow. Warm water, warm food, warm thoughts."
                ]
            } else if isEvening {
                return [
                    "Wind down early tonight. Rest fuels recovery.",
                    "You've honored your body today. Now rest.",
                    "Early to bed. Tomorrow rebuilds from tonight."
                ]
            } else {
                return [
                    "Rest is productive today — honor your body's need to slow down.",
                    "Midday pause. Listen to what your body needs.",
                    "Keep it gentle. You're doing the work just by resting."
                ]
            }

        case "follicular":
            if isMorning {
                return [
                    "Fresh energy this morning. What will you start?",
                    "Your body is primed for something ambitious today.",
                    "Rising estrogen, rising possibility. Go for it."
                ]
            } else if isEvening {
                return [
                    "Good energy today? Channel it into tomorrow's plan.",
                    "Building momentum. Keep the streak going.",
                    "Your body is ramping up. Rest well to fuel it."
                ]
            } else {
                return [
                    "Your energy is building — great day for trying something new.",
                    "Midday and rising. This is your creative window.",
                    "Follicular flow. Try that thing you've been putting off."
                ]
            }

        case "ovulatory":
            if isMorning {
                return [
                    "Peak morning. You're at your most magnetic today.",
                    "Everything is firing — energy, mood, confidence.",
                    "Your body is peaking. Show up big today."
                ]
            } else if isEvening {
                return [
                    "What a day. Peak energy well spent.",
                    "You showed up fully today. Well done.",
                    "Peak phase evenings — socialize, celebrate, connect."
                ]
            } else {
                return [
                    "Peak energy and confidence — make the most of it.",
                    "Ovulatory power hour. This is your time.",
                    "You're radiating. Make that call, send that message."
                ]
            }

        case "luteal":
            if isMorning {
                return [
                    "Gentle morning. Your body is shifting gears.",
                    "Progesterone rising. Warm breakfast, slow start.",
                    "Cozy morning energy. Lean into the quiet."
                ]
            } else if isEvening {
                return [
                    "Nesting time. Comfort food and early wind-down.",
                    "Your body wants rest. Give it what it needs.",
                    "Luteal evenings are for comfort. No guilt."
                ]
            } else {
                return [
                    "Winding down — focus on comfort foods and gentle movement.",
                    "Afternoon in the luteal phase. Keep it light.",
                    "Progesterone is peaking. Shorter workout, richer meal."
                ]
            }

        default:
            return ["Welcome back."]
        }
    }
}
