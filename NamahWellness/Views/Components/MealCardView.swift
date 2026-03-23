import SwiftUI

/// Legacy wrapper — uses MealCardContent internally.
/// TodayView will migrate to using MealCardContent + SwipeActionWrapper directly.
struct MealCardView: View {
    let meal: Meal
    let isCompleted: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            MealCardContent(meal: meal, isCompleted: isCompleted)
        }
        .buttonStyle(.plain)
    }
}
