import SwiftUI
import SwiftData

struct AddPlanItemSheet: View {
    let defaultCategory: HabitCategory
    let phaseSlug: String
    let allowedCategories: [HabitCategory]

    // Pre-fill from a meal being replaced
    var replacingMealType: String?
    var replacingTime: String?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncService.self) private var syncService

    @State private var category: HabitCategory
    @State private var title = ""
    @State private var subtitle = ""
    @State private var time = "7:00am"

    // Meal fields
    @State private var mealType = "Breakfast"
    @State private var calories = ""
    @State private var proteinG = ""
    @State private var carbsG = ""
    @State private var fatG = ""

    // Workout fields
    @State private var workoutFocus = "Strength"
    @State private var duration = ""

    // Grocery fields
    @State private var groceryCategory = "Produce"

    // Recurrence
    @State private var recurrence: HabitRecurrence = .specificDays
    @State private var selectedDays: Set<Int> = []  // 0=Monday

    private let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let mealTypes = ["Breakfast", "Lunch", "Dinner", "Snack"]
    private let workoutFocuses = ["Strength", "Cardio", "Yoga", "Core", "Other"]
    private let groceryCategories = ["Protein", "Produce", "Pantry / Grains", "Other"]

    private var phaseColors: PhaseColors { PhaseColors.forSlug(phaseSlug) }

    private var canSave: Bool { !title.isEmpty }

    init(
        defaultCategory: HabitCategory = .meal,
        phaseSlug: String,
        allowedCategories: [HabitCategory] = HabitCategory.allCases,
        replacingMealType: String? = nil,
        replacingTime: String? = nil
    ) {
        self.defaultCategory = defaultCategory
        self.phaseSlug = phaseSlug
        self.allowedCategories = allowedCategories
        self.replacingMealType = replacingMealType
        self.replacingTime = replacingTime
        _category = State(initialValue: defaultCategory)

        // Default to current weekday for weekly recurrence
        let weekday = Calendar.current.component(.weekday, from: Date())
        let dayIndex = weekday == 1 ? 6 : weekday - 2  // 0=Monday
        _selectedDays = State(initialValue: [dayIndex])

        // Pre-fill from replacement
        if let mt = replacingMealType { _mealType = State(initialValue: mt) }
        if let t = replacingTime { _time = State(initialValue: t) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Category picker
                    if replacingMealType == nil {
                        categoryPicker
                    }

                    // Common fields
                    commonFields

                    // Category-specific fields
                    switch category {
                    case .meal: mealFields
                    case .workout: workoutFields
                    case .grocery: groceryFields
                    case .habit: habitFields
                    case .medication, .supplement: EmptyView()
                    }

                    // Recurrence (not for grocery)
                    if category != .grocery {
                        recurrenceSection
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Add \(category.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TYPE")
                .namahLabel()

            HStack(spacing: 8) {
                ForEach(allowedCategories, id: \.rawValue) { cat in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            category = cat
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 12))
                            Text(cat.displayName)
                                .font(.nCaption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .foregroundStyle(category == cat ? .white : .secondary)
                        .background(category == cat ? phaseColors.color : Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Common Fields

    private var commonFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category == .grocery ? "ITEM NAME" : "TITLE")
                .namahLabel()

            TextField(
                category == .meal ? "e.g., Avocado Toast" :
                category == .workout ? "e.g., Morning Yoga" :
                "e.g., Almond Milk",
                text: $title
            )
            .font(.nSubheadline)
            .padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if category != .grocery {
                TextField("Description (optional)", text: $subtitle)
                    .font(.nCaption)
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Meal Fields

    private var mealFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MEAL TYPE")
                .namahLabel()

            HStack(spacing: 6) {
                ForEach(mealTypes, id: \.self) { type in
                    Button {
                        mealType = type
                        time = defaultTime(for: type)
                    } label: {
                        Text(type)
                            .font(.nCaption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .foregroundStyle(mealType == type ? .white : .secondary)
                            .background(mealType == type ? phaseColors.color : Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("TIME")
                .namahLabel()

            TextField("7:00am", text: $time)
                .font(.nSubheadline)
                .padding(14)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("MACROS (OPTIONAL)")
                .namahLabel()

            HStack(spacing: 8) {
                macroField("Cal", text: $calories)
                macroField("P (g)", text: $proteinG)
                macroField("C (g)", text: $carbsG)
                macroField("F (g)", text: $fatG)
            }
        }
    }

    private func macroField(_ label: String, text: Binding<String>) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.nCaption2)
                .foregroundStyle(.secondary)
            TextField("—", text: text)
                .font(.nCaption)
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .padding(10)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Workout Fields

    private var workoutFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FOCUS")
                .namahLabel()

            HStack(spacing: 6) {
                ForEach(workoutFocuses, id: \.self) { focus in
                    Button {
                        workoutFocus = focus
                    } label: {
                        Text(focus)
                            .font(.nCaption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .foregroundStyle(workoutFocus == focus ? .white : .secondary)
                            .background(workoutFocus == focus ? phaseColors.color : Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TIME")
                        .namahLabel()
                    TextField("9:00am", text: $time)
                        .font(.nSubheadline)
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("DURATION")
                        .namahLabel()
                    TextField("30 min", text: $duration)
                        .font(.nSubheadline)
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Habit Fields

    private var habitFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TIME (OPTIONAL)")
                        .namahLabel()
                    TextField("7:00am", text: $time)
                        .font(.nSubheadline)
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("DURATION")
                        .namahLabel()
                    TextField("10 min", text: $duration)
                        .font(.nSubheadline)
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Grocery Fields

    private var groceryFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CATEGORY")
                .namahLabel()

            HStack(spacing: 6) {
                ForEach(groceryCategories, id: \.self) { cat in
                    Button {
                        groceryCategory = cat
                    } label: {
                        Text(cat)
                            .font(.nCaption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .foregroundStyle(groceryCategory == cat ? .white : .secondary)
                            .background(groceryCategory == cat ? phaseColors.color : Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Recurrence

    private var recurrenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("REPEATS")
                .namahLabel()

            // Recurrence type picker
            HStack(spacing: 6) {
                ForEach(HabitRecurrence.allCases, id: \.rawValue) { rec in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            recurrence = rec
                        }
                    } label: {
                        Text(rec.displayName)
                            .font(.nCaption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .foregroundStyle(recurrence == rec ? .white : .secondary)
                            .background(recurrence == rec ? phaseColors.color : Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Day picker for specific_days
            if recurrence == .specificDays {
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { index in
                        Button {
                            if selectedDays.contains(index) {
                                selectedDays.remove(index)
                            } else {
                                selectedDays.insert(index)
                            }
                        } label: {
                            Text(dayLabels[index])
                                .font(.sans(11))
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundStyle(selectedDays.contains(index) ? .white : .secondary)
                                .background(selectedDays.contains(index) ? phaseColors.color : Color(uiColor: .secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func defaultTime(for mealType: String) -> String {
        switch mealType {
        case "Breakfast": return "7:00am"
        case "Lunch": return "12:00pm"
        case "Dinner": return "6:30pm"
        case "Snack": return "3:00pm"
        default: return "12:00pm"
        }
    }

    private func save() {
        let recDays: String? = recurrence == .specificDays
            ? selectedDays.sorted().map(String.init).joined(separator: ",")
            : nil

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        let todayStr = recurrence == .once ? formatter.string(from: Date()) : nil

        let item = Habit(
            category: category,
            title: title,
            subtitle: subtitle.isEmpty ? nil : subtitle,
            time: category != .grocery ? time : nil,
            recurrence: recurrence,
            recurrenceDays: recDays,
            specificDate: todayStr,
            mealType: category == .meal ? mealType : nil,
            calories: category == .meal && !calories.isEmpty ? calories : nil,
            proteinG: category == .meal ? Int(proteinG) : nil,
            carbsG: category == .meal ? Int(carbsG) : nil,
            fatG: category == .meal ? Int(fatG) : nil,
            workoutFocus: category == .workout ? workoutFocus : nil,
            duration: category == .workout && !duration.isEmpty ? duration : nil,
            groceryCategory: category == .grocery ? groceryCategory : nil
        )

        modelContext.insert(item)
        syncService.queueChange(
            table: "habits", action: "upsert",
            data: ["id": item.id], modelContext: modelContext
        )

        dismiss()
    }
}
