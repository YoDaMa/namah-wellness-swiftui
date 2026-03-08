import SwiftUI
import SwiftData

struct SupplementsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var definitions: [SupplementDefinition]
    @Query private var nutrients: [SupplementNutrient]
    @Query private var userSupplements: [UserSupplement]
    @Query private var supplementLogs: [SupplementLog]

    @State private var showBrowse = false
    @State private var searchText = ""
    @State private var showAddCustom = false

    private var today: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private var activeRegimen: [UserSupplement] { userSupplements.filter { $0.isActive } }
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
                ContentUnavailableView(
                    "No Supplements",
                    systemImage: "pill",
                    description: Text("Browse the library to add supplements to your regimen.")
                )
            } else {
                regimenView
            }

            Button { showBrowse = true } label: {
                Label("Browse Supplements", systemImage: "plus.magnifyingglass")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showBrowse) { browseSheet }
        .sheet(isPresented: $showAddCustom) { AddCustomSupplementView() }
    }

    // MARK: - Regimen

    private var regimenView: some View {
        VStack(alignment: .leading, spacing: 16) {
            let takenCount = activeRegimen.filter { todayLogIds.contains($0.id) }.count
            Text("\(takenCount) of \(activeRegimen.count) taken today")
                .font(.footnote)
                .fontWeight(.medium)

            ForEach(timeSlots, id: \.0) { slot, label in
                let slotItems = activeRegimen.filter { $0.timeOfDay == slot }
                if !slotItems.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(label.uppercased())
                            .font(.caption2)
                            .fontWeight(.medium)
                            .textCase(.uppercase)
                            .tracking(2)
                            .foregroundStyle(.secondary)

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
        let supNutrients = nutrients.filter { $0.supplementId == userSup.supplementId }

        return Button { toggleTaken(userSup) } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isTaken ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isTaken ? Color.phaseF : Color(uiColor: .tertiaryLabel))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(def?.name ?? "Unknown")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(isTaken ? .secondary : .primary)
                        .strikethrough(isTaken)

                    HStack(spacing: 8) {
                        if let brand = def?.brand, !brand.isEmpty {
                            Text(brand)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(Int(userSup.dosage)) \(def?.servingUnit ?? "dose")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !supNutrients.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(supNutrients.prefix(3), id: \.id) { n in
                                Text("\(n.nutrientKey): \(formatAmount(n.amount))\(n.unit)")
                                    .font(.caption2)
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
                        .font(.system(size: 9, weight: .medium))
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

    // MARK: - Browse Sheet

    private var browseSheet: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showBrowse = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showAddCustom = true
                        }
                    } label: {
                        Label("Create Custom Supplement", systemImage: "plus")
                    }
                }

                let filtered = filteredDefinitions
                let cats = Array(Set(filtered.map(\.category))).sorted()

                ForEach(cats, id: \.self) { cat in
                    Section(cat) {
                        ForEach(filtered.filter { $0.category == cat }, id: \.id) { def in
                            browseRow(def)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search supplements")
            .navigationTitle("Supplements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showBrowse = false }
                }
            }
        }
    }

    private var filteredDefinitions: [SupplementDefinition] {
        if searchText.isEmpty { return definitions }
        let q = searchText.lowercased()
        return definitions.filter {
            $0.name.lowercased().contains(q) || $0.category.lowercased().contains(q)
        }
    }

    private func browseRow(_ def: SupplementDefinition) -> some View {
        let inRegimen = userSupplements.contains { $0.supplementId == def.id && $0.isActive }

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(def.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack(spacing: 6) {
                    if let brand = def.brand, !brand.isEmpty {
                        Text(brand)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(def.servingSize) \(def.servingUnit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if inRegimen {
                Image(systemName: "checkmark")
                    .foregroundStyle(.phaseF)
            } else {
                Button("Add") { addToRegimen(def) }
                    .font(.caption)
                    .fontWeight(.medium)
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Actions

    private func toggleTaken(_ userSup: UserSupplement) {
        if let existing = supplementLogs.first(where: { $0.userSupplementId == userSup.id && $0.date == today }) {
            existing.taken.toggle()
            existing.loggedAt = Date()
        } else {
            modelContext.insert(SupplementLog(userSupplementId: userSup.id, date: today, taken: true))
        }
    }

    private func addToRegimen(_ def: SupplementDefinition) {
        modelContext.insert(UserSupplement(
            supplementId: def.id, dosage: Double(def.servingSize),
            frequency: "daily", timeOfDay: "morning"
        ))
    }

    private func removeFromRegimen(_ userSup: UserSupplement) { userSup.isActive = false }

    private func formatAmount(_ amount: Double) -> String {
        amount == amount.rounded() ? "\(Int(amount))" : String(format: "%.1f", amount)
    }
}

// MARK: - Add Custom Supplement

struct AddCustomSupplementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var brand = ""
    @State private var category = "Vitamins"
    @State private var servingSize = "1"
    @State private var servingUnit = "capsule"
    @State private var addToRegimen = true

    private let categories = ["Vitamins", "Minerals", "Omega / Fatty Acids", "Herbal", "Probiotics", "Amino Acids", "Other"]
    private let units = ["capsule", "tablet", "softgel", "scoop", "ml", "drops"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    TextField("Brand (optional)", text: $brand)
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                }

                Section("Serving") {
                    TextField("Size", text: $servingSize)
                        .keyboardType(.numberPad)
                    Picker("Unit", selection: $servingUnit) {
                        ForEach(units, id: \.self) { Text($0) }
                    }
                }

                Section {
                    Toggle("Add to my regimen", isOn: $addToRegimen)
                }
            }
            .navigationTitle("New Supplement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.isEmpty)
                }
            }
        }
    }

    private func save() {
        let def = SupplementDefinition(
            name: name, brand: brand.isEmpty ? nil : brand,
            category: category, servingSize: Int(servingSize) ?? 1,
            servingUnit: servingUnit, isCustom: true
        )
        modelContext.insert(def)
        if addToRegimen {
            modelContext.insert(UserSupplement(
                supplementId: def.id, dosage: Double(Int(servingSize) ?? 1),
                frequency: "daily", timeOfDay: "morning"
            ))
        }
        dismiss()
    }
}
