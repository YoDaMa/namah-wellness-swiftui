import SwiftUI
import SwiftData

struct PlanSupplementsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService
    @Query private var definitions: [SupplementDefinition]
    @Query private var supplementNutrients: [SupplementNutrient]
    @Query private var userSupplements: [UserSupplement]
    @Query private var supplementLogs: [SupplementLog]

    @State private var showBrowse = false

    private var activeRegimen: [UserSupplement] { userSupplements.filter { $0.isActive } }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var today: String {
        Self.dayFormatter.string(from: Date())
    }

    private var todayLogIds: Set<String> {
        Set(supplementLogs.filter { $0.date == today && $0.taken }.map(\.userSupplementId))
    }

    private let timeSlots = [
        ("morning", "Morning"),
        ("with_meals", "With Meals"),
        ("evening", "Evening"),
        ("as_needed", "As Needed"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if activeRegimen.isEmpty {
                emptyState
            } else {
                regimenView
                nutrientLabel
            }

            browseButton
        }
        .sheet(isPresented: $showBrowse) { BrowseSupplementsSheet() }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Button { showBrowse = true } label: {
            HStack(spacing: 8) {
                Text("No supplements yet")
                    .font(.nSubheadline)
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.tertiary)
                Text("Browse library")
                    .font(.nSubheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Regimen

    private var regimenView: some View {
        VStack(alignment: .leading, spacing: 16) {
            let takenCount = activeRegimen.filter { todayLogIds.contains($0.id) }.count
            Text("\(takenCount) of \(activeRegimen.count) taken today")
                .font(.nFootnote)
                .fontWeight(.medium)

            ForEach(timeSlots, id: \.0) { slot, label in
                let slotItems = activeRegimen.filter { $0.timeOfDay == slot }
                if !slotItems.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(label.uppercased())
                            .namahLabel()

                        ForEach(slotItems, id: \.id) { userSup in
                            supplementCard(userSup)
                        }
                    }
                }
            }
        }
    }

    private func supplementCard(_ userSup: UserSupplement) -> some View {
        let def = definitions.first { $0.id == userSup.supplementId }
        let isTaken = todayLogIds.contains(userSup.id)
        let supNuts = supplementNutrients.filter { $0.supplementId == userSup.supplementId }

        return Button { toggleTaken(userSup) } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isTaken ? "checkmark.circle.fill" : "circle")
                    .font(.sans(18))
                    .foregroundStyle(isTaken ? Color.phaseF : Color(uiColor: .tertiaryLabel))
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
                        Text("\(Int(userSup.dosage)) \(def?.servingUnit ?? "dose")")
                            .font(.nCaption)
                            .foregroundStyle(.secondary)
                    }

                    if !supNuts.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(supNuts.prefix(3), id: \.id) { n in
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

                Button { removeFromRegimen(userSup) } label: {
                    Image(systemName: "xmark")
                        .font(.sans(9)).fontWeight(.medium)
                        .foregroundStyle(.tertiary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Nutrient Label

    private struct AggregatedNutrient: Identifiable {
        let id: String
        let name: String
        let amount: Double
        let unit: String
    }

    private static let nutrientDisplayNames: [String: String] = [
        "vitaminA": "Vitamin A",
        "vitaminB1": "Vitamin B1 (Thiamine)",
        "vitaminB2": "Vitamin B2 (Riboflavin)",
        "vitaminB3": "Vitamin B3 (Niacin)",
        "vitaminB5": "Vitamin B5 (Pantothenic Acid)",
        "vitaminB6": "Vitamin B6",
        "vitaminB7": "Vitamin B7 (Biotin)",
        "vitaminB9": "Folate",
        "vitaminB12": "Vitamin B12",
        "vitaminC": "Vitamin C",
        "vitaminD": "Vitamin D",
        "vitaminD3": "Vitamin D3",
        "vitaminE": "Vitamin E",
        "vitaminK": "Vitamin K",
        "vitaminK2": "Vitamin K2",
        "calcium": "Calcium",
        "iron": "Iron",
        "magnesium": "Magnesium",
        "zinc": "Zinc",
        "selenium": "Selenium",
        "chromium": "Chromium",
        "copper": "Copper",
        "manganese": "Manganese",
        "iodine": "Iodine",
        "potassium": "Potassium",
        "sodium": "Sodium",
        "phosphorus": "Phosphorus",
        "omega3": "Omega-3",
        "omega3EPA": "EPA",
        "omega3DHA": "DHA",
        "omega3ALA": "ALA",
        "omega6": "Omega-6",
        "fiber": "Fiber",
        "protein": "Protein",
        "probiotics": "Probiotics",
        "collagen": "Collagen",
        "ashwagandha": "Ashwagandha",
        "turmeric": "Turmeric",
        "curcumin": "Curcumin",
        "coq10": "CoQ10",
        "l_theanine": "L-Theanine",
        "melatonin": "Melatonin",
    ]

    private var aggregatedNutrients: [AggregatedNutrient] {
        let activeSupplementIds = Set(activeRegimen.map(\.supplementId))
        let relevantNutrients = supplementNutrients.filter { activeSupplementIds.contains($0.supplementId) }

        var grouped: [String: (amount: Double, unit: String)] = [:]
        for n in relevantNutrients {
            let existing = grouped[n.nutrientKey]
            if let existing {
                grouped[n.nutrientKey] = (existing.amount + n.amount, n.unit)
            } else {
                grouped[n.nutrientKey] = (n.amount, n.unit)
            }
        }

        return grouped
            .map { AggregatedNutrient(id: $0.key, name: Self.nutrientDisplayNames[$0.key] ?? $0.key, amount: $0.value.amount, unit: $0.value.unit) }
            .sorted { $0.name < $1.name }
    }

    @ViewBuilder
    private var nutrientLabel: some View {
        let nutrients = aggregatedNutrients
        if !nutrients.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("DAILY TOTALS")
                    .namahLabel()
                    .padding(.bottom, 8)

                VStack(spacing: 0) {
                    // Top thick border
                    Rectangle()
                        .fill(Color.primary)
                        .frame(height: 8)

                    ForEach(Array(nutrients.enumerated()), id: \.element.id) { index, nutrient in
                        HStack {
                            Text(nutrient.name)
                                .font(.nSubheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(formatAmount(nutrient.amount)) \(nutrient.unit)")
                                .font(.nSubheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                        if index < nutrients.count - 1 {
                            Divider().padding(.leading, 12)
                        }
                    }

                    // Bottom thick border
                    Rectangle()
                        .fill(Color.primary)
                        .frame(height: 4)
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 2))
            }
        }
    }

    // MARK: - Browse Button

    private var browseButton: some View {
        Button { showBrowse = true } label: {
            Label("Browse Supplements", systemImage: "plus.magnifyingglass")
                .font(.nSubheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func toggleTaken(_ userSup: UserSupplement) {
        if let existing = supplementLogs.first(where: { $0.userSupplementId == userSup.id && $0.date == today }) {
            existing.taken.toggle()
            existing.loggedAt = Date()
            syncService.queueChange(table: "supplementLogs", action: "upsert",
                                    data: ["id": existing.id, "userSupplementId": userSup.id,
                                           "date": today, "taken": existing.taken],
                                    modelContext: modelContext)
        } else {
            let log = SupplementLog(userSupplementId: userSup.id, date: today, taken: true)
            modelContext.insert(log)
            syncService.queueChange(table: "supplementLogs", action: "upsert",
                                    data: ["id": log.id, "userSupplementId": userSup.id,
                                           "date": today, "taken": true],
                                    modelContext: modelContext)
        }
    }

    private func removeFromRegimen(_ userSup: UserSupplement) {
        userSup.isActive = false
        syncService.queueChange(
            table: "userSupplements", action: "upsert",
            data: [
                "id": userSup.id, "supplementId": userSup.supplementId,
                "dosage": userSup.dosage, "frequency": userSup.frequency,
                "timeOfDay": userSup.timeOfDay, "isActive": false,
            ],
            modelContext: modelContext
        )
    }

    private func formatAmount(_ amount: Double) -> String {
        amount == amount.rounded() ? "\(Int(amount))" : String(format: "%.1f", amount)
    }
}
