import SwiftUI

/// Renders a single time block (Morning, Midday, Afternoon, Evening) with its items.
///
/// Items are passed in pre-grouped — this view only handles presentation:
///   - Focus state (current block highlighted)
///   - Completion tracking
///   - "All done" state with next block preview
///
struct TimeBlockSectionView: View {
    let block: TimeBlock
    let isCurrent: Bool
    let meals: [MealItem]
    let supplements: [SupplementItem]
    let workoutSessions: [WorkoutSessionItem]
    let habitItems: [HabitItem]
    let isCheckInBlock: Bool
    let hasCheckedIn: Bool
    let nextBlockName: String?
    let nextBlockTime: String?
    let phaseColor: Color

    let onToggleMeal: (String) -> Void
    let onTapMeal: (MealItem) -> Void
    let onToggleSupplement: (String) -> Void
    let onCheckIn: () -> Void
    let onToggleWorkout: (String) -> Void
    let onTapWorkout: (WorkoutSessionItem) -> Void
    var onToggleHabit: ((String) -> Void)? = nil

    struct MealItem: Identifiable {
        let id: String
        let meal: Meal?
        let customItem: Habit?
        let isCompleted: Bool
        let isCustom: Bool

        init(id: String, meal: Meal, isCompleted: Bool) {
            self.id = id
            self.meal = meal
            self.customItem = nil
            self.isCompleted = isCompleted
            self.isCustom = false
        }

        init(id: String, customItem: Habit, isCompleted: Bool) {
            self.id = id
            self.meal = nil
            self.customItem = customItem
            self.isCompleted = isCompleted
            self.isCustom = true
        }
    }

    struct SupplementItem: Identifiable {
        let id: String
        let userSupplement: UserSupplement
        let definition: SupplementDefinition?
        let nutrients: [SupplementNutrient]
        let isTaken: Bool
    }

    struct WorkoutSessionItem: Identifiable {
        let id: String
        let session: WorkoutSession?
        let customItem: Habit?
        let isRestDay: Bool
        let dayFocus: String
        let isCustom: Bool
        let isCompleted: Bool

        init(id: String, session: WorkoutSession, isRestDay: Bool, dayFocus: String, isCompleted: Bool) {
            self.id = id
            self.session = session
            self.customItem = nil
            self.isRestDay = isRestDay
            self.dayFocus = dayFocus
            self.isCustom = false
            self.isCompleted = isCompleted
        }

        init(id: String, customItem: Habit, isCompleted: Bool) {
            self.id = id
            self.session = nil
            self.customItem = customItem
            self.isRestDay = false
            self.dayFocus = customItem.workoutFocus ?? ""
            self.isCustom = true
            self.isCompleted = isCompleted
        }
    }

    struct HabitItem: Identifiable {
        let id: String
        let habit: Habit
        let isCompleted: Bool
    }

    private var totalItems: Int {
        meals.count + supplements.count + workoutSessions.count + habitItems.count
    }

    private var completedItems: Int {
        meals.filter(\.isCompleted).count + supplements.filter(\.isTaken).count + workoutSessions.filter(\.isCompleted).count + habitItems.filter(\.isCompleted).count
    }

    private var allDone: Bool {
        totalItems > 0 && completedItems >= totalItems
    }

    private var isEmpty: Bool {
        meals.isEmpty && supplements.isEmpty && workoutSessions.isEmpty && habitItems.isEmpty && !isCheckInBlock
    }

    var body: some View {
        if !isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                // Block header
                blockHeader

                // Items
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(meals) { item in
                        mealRow(item)
                    }

                    ForEach(supplements) { item in
                        supplementRow(item)
                    }

                    ForEach(workoutSessions) { item in
                        Button {
                            onToggleWorkout(item.id)
                        } label: {
                            if item.session != nil {
                                workoutRowContent(item)
                            } else if item.customItem != nil {
                                customWorkoutRowContent(item)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(habitItems) { item in
                        habitRow(item)
                    }

                    if isCheckInBlock {
                        checkInRow
                    }
                }

            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Block Header

    private var blockHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: block.icon)
                .font(.sans(13))
                .foregroundStyle(isCurrent ? phaseColor : .secondary)

            Text(block.displayName.uppercased())
                .font(.nCaption2)
                .fontWeight(.semibold)
                .tracking(2)
                .foregroundStyle(isCurrent ? phaseColor : .secondary)

            Text(block.startTimeLabel + " – " + block.endTimeLabel)
                .font(.nCaption2)
                .foregroundStyle(.tertiary)

            Spacer()

            if isCurrent {
                Text("NOW")
                    .font(.nCaption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .glassEffect(.regular.tint(phaseColor))
            } else if allDone && totalItems > 0 {
                Image(systemName: "checkmark.circle.fill")
                    .font(.sans(14))
                    .foregroundStyle(phaseColor)
            }
        }
    }

    // MARK: - Meal Row

    private func mealRow(_ item: MealItem) -> some View {
        HStack(spacing: 0) {
            // Tap card body → toggle completion
            Button {
                onToggleMeal(item.id)
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.sans(18))
                        .foregroundStyle(item.isCompleted ? (item.isCustom ? phaseColor : .secondary) : item.isCustom ? Color(uiColor: .tertiaryLabel) : .primary)
                        .padding(.top, 2)

                    mealTextContent(item)

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            // Chevron → open detail
            Button { onTapMeal(item) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 32)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(item.isCustom ? phaseColor.opacity(0.08) : Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            if item.isCustom {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(phaseColor.opacity(0.2), lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    private func mealTextContent(_ item: MealItem) -> some View {
        if let meal = item.meal {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(meal.time)
                        .font(.nCaption2)
                        .fontWeight(.medium)
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.tertiary)
                    Text(meal.mealType)
                        .font(.nCaption2)
                        .fontWeight(.medium)
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundStyle(.tertiary)
                }
                Text(meal.title)
                    .font(.nSubheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    .strikethrough(item.isCompleted)
                if let p = meal.proteinG, let c = meal.carbsG, let f = meal.fatG {
                    let macroText = "\(p)P · \(c)C · \(f)F · \(meal.calories)"
                    Text(macroText)
                        .font(.nCaption2)
                        .foregroundStyle(.tertiary)
                }
            }
        } else if let custom = item.customItem {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if let time = custom.time {
                        Text(time)
                            .font(.nCaption2)
                            .fontWeight(.medium)
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundStyle(.secondary)
                    }
                    Text("CUSTOM")
                        .font(.sans(7))
                        .fontWeight(.bold)
                        .tracking(0.5)
                        .foregroundStyle(phaseColor)
                }
                Text(custom.title)
                    .font(.nSubheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    .strikethrough(item.isCompleted)
            }
        }
    }

    // MARK: - Supplement Row

    private func supplementRow(_ item: SupplementItem) -> some View {
        let def = item.definition
        let isTaken = item.isTaken

        return Button { onToggleSupplement(item.id) } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isTaken ? "checkmark.circle.fill" : "circle")
                    .font(.sans(18))
                    .foregroundStyle(isTaken ? phaseColor : Color(uiColor: .tertiaryLabel))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(def?.name ?? "Unknown")
                        .font(.nSubheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(isTaken ? .secondary : .primary)
                        .strikethrough(isTaken)

                    HStack(spacing: 8) {
                        if let brand = def?.brand, !brand.isEmpty {
                            Text(brand)
                                .font(.nCaption)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(Int(item.userSupplement.dosage)) \(def?.servingUnit ?? "dose")")
                            .font(.nCaption)
                            .foregroundStyle(.secondary)
                    }

                    if !item.nutrients.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(item.nutrients.prefix(3), id: \.id) { n in
                                Text("\(n.nutrientKey): \(formatAmount(n.amount))\(n.unit)")
                                    .font(.nCaption2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(uiColor: .tertiarySystemFill))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Workout Row

    @ViewBuilder
    private func workoutRowContent(_ item: WorkoutSessionItem) -> some View {
        if let session = item.session {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.sans(18))
                .foregroundStyle(item.isCompleted ? phaseColor : Color(uiColor: .tertiaryLabel))
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(session.timeSlot)
                        .font(.nCaption2)
                        .fontWeight(.medium)
                        .foregroundStyle(phaseColor)
                    if !item.dayFocus.isEmpty {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(item.dayFocus)
                            .font(.nCaption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(session.title.replacingOccurrences(of: ".$", with: "", options: .regularExpression))
                    .font(.nSubheadline)
                    .fontWeight(.medium)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)

                Text(session.sessionDescription)
                    .font(.nCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Custom Workout Row Content

    @ViewBuilder
    private func customWorkoutRowContent(_ item: WorkoutSessionItem) -> some View {
        if let custom = item.customItem {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.sans(18))
                .foregroundStyle(item.isCompleted ? phaseColor : Color(uiColor: .tertiaryLabel))
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if let time = custom.time {
                        Text(time)
                            .font(.nCaption2)
                            .fontWeight(.medium)
                            .foregroundStyle(phaseColor)
                    }
                    Text("CUSTOM")
                        .font(.sans(7))
                        .fontWeight(.bold)
                        .tracking(0.5)
                        .foregroundStyle(phaseColor)
                    if let focus = custom.workoutFocus {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(focus)
                            .font(.nCaption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(custom.title)
                    .font(.nSubheadline)
                    .fontWeight(.medium)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)

                if let sub = custom.subtitle, !sub.isEmpty {
                    Text(sub)
                        .font(.nCaption)
                        .foregroundStyle(.secondary)
                }

                if let dur = custom.duration {
                    Text(dur)
                        .font(.nCaption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(phaseColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(phaseColor.opacity(0.2), lineWidth: 1)
        )
        }
    }

    // MARK: - Custom Meal Row

    private func customMealRow(_ item: Habit, isCompleted: Bool, onToggle: @escaping () -> Void) -> some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.sans(18))
                    .foregroundStyle(isCompleted ? phaseColor : Color(uiColor: .tertiaryLabel))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        if let time = item.time {
                            Text(time)
                                .font(.nCaption2)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        }
                        if let mt = item.mealType {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text(mt.uppercased())
                                .font(.sans(8))
                                .fontWeight(.medium)
                                .tracking(1)
                                .foregroundStyle(.secondary)
                        }
                        Text("CUSTOM")
                            .font(.sans(7))
                            .fontWeight(.bold)
                            .tracking(0.5)
                            .foregroundStyle(phaseColor)
                    }

                    Text(item.title)
                        .font(.nSubheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(isCompleted ? .secondary : .primary)
                        .strikethrough(isCompleted)

                    if let sub = item.subtitle, !sub.isEmpty {
                        Text(sub)
                            .font(.nCaption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    if let p = item.proteinG, let c = item.carbsG, let f = item.fatG {
                        Text("\(p)P · \(c)C · \(f)F")
                            .font(.nCaption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(phaseColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(phaseColor.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Habit Row

    private func habitRow(_ item: HabitItem) -> some View {
        Button {
            onToggleHabit?(item.id)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.sans(18))
                    .foregroundStyle(item.isCompleted ? phaseColor : Color(uiColor: .tertiaryLabel))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                            .foregroundStyle(phaseColor)
                        Text(item.habit.title)
                            .font(.nSubheadline)
                            .fontWeight(.medium)
                            .strikethrough(item.isCompleted, color: .secondary)
                            .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    }

                    if let duration = item.habit.duration, !duration.isEmpty {
                        Text(duration)
                            .font(.nCaption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Check-In Row

    private var checkInRow: some View {
        Button(action: onCheckIn) {
            HStack(spacing: 12) {
                Image(systemName: hasCheckedIn ? "checkmark.circle.fill" : "heart.text.square")
                    .font(.sans(18))
                    .foregroundStyle(hasCheckedIn ? phaseColor : Color(uiColor: .tertiaryLabel))

                VStack(alignment: .leading, spacing: 2) {
                    Text(hasCheckedIn ? "Adjust today's check-in" : "Evening check-in")
                        .font(.nSubheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(hasCheckedIn ? .secondary : .primary)
                    if !hasCheckedIn {
                        Text("Log symptoms, flow, and how you're feeling")
                            .font(.nCaption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.nCaption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(phaseColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(phaseColor.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func formatAmount(_ amount: Double) -> String {
        amount == amount.rounded() ? "\(Int(amount))" : String(format: "%.1f", amount)
    }
}
