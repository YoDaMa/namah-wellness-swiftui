import SwiftUI
import SwiftData

/// Grocery list presented as a bottom sheet from the Nourish sub-page.
/// Phase color accent on header, category sections, persistent checkboxes, share button.
struct GroceryListView: View {
    let phaseSlug: String
    let phaseColor: Color

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncService.self) private var syncService
    @Query private var phases: [Phase]
    @Query private var groceryItems: [GroceryItem]
    @Query private var groceryChecks: [GroceryCheck]
    @Query private var userPlanItems: [UserPlanItem]
    @Query private var userItemsHidden: [UserItemHidden]

    @State private var showAddGrocery = false

    private var phase: Phase? { phases.first { $0.slug == phaseSlug } }

    private var hiddenIds: Set<String> {
        Set(userItemsHidden.map(\.itemId))
    }

    private var customGrocery: [UserPlanItem] {
        userPlanItems.filter { $0.category == .grocery && $0.isActive }
    }

    private var items: [GroceryItem] {
        guard let p = phase else { return [] }
        return groceryItems.filter { $0.phaseId == p.id && !hiddenIds.contains($0.id) }
    }

    private var totalItemCount: Int { items.count + customGrocery.count }

    private var checkedIds: Set<String> {
        Set(groceryChecks.filter { $0.checked }.map(\.groceryItemId))
    }

    private var checkedCount: Int {
        let templateChecked = items.filter { checkedIds.contains($0.id) }.count
        let customChecked = customGrocery.filter { checkedIds.contains($0.id) }.count
        return templateChecked + customChecked
    }
    private var progress: Double { totalItemCount == 0 ? 0 : Double(checkedCount) / Double(totalItemCount) }

    private let categories = ["Protein", "Produce", "Pantry / Grains", "Other"]

    private var phaseColors: PhaseColors { PhaseColors.forSlug(phaseSlug) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Phase-tinted header with progress
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "bag")
                                .font(.sans(16))
                                .foregroundStyle(phaseColor)
                            Text(phase?.name ?? "")
                                .font(.nCaption)
                                .fontWeight(.bold)
                                .foregroundStyle(phaseColor)
                            Spacer()
                            if checkedCount > 0 {
                                Button("Reset") { resetAll() }
                                    .font(.nCaption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack {
                            Text("\(checkedCount) of \(totalItemCount) items")
                                .font(.nFootnote)
                                .fontWeight(.medium)
                            Spacer()
                        }

                        ProgressView(value: progress)
                            .tint(phaseColor)
                    }
                    .padding(16)
                    .background(phaseColors.soft)

                    // Category sections (template items)
                    ForEach(categories, id: \.self) { category in
                        let catItems = items.filter { $0.category == category }
                        let customCatItems = customGrocery.filter { ($0.groceryCategory ?? "Other") == category }
                        if !catItems.isEmpty || !customCatItems.isEmpty {
                            categorySection(category, items: catItems, customItems: customCatItems)
                        }
                    }

                    // Add custom grocery item button
                    Button { showAddGrocery = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.sans(16))
                                .foregroundStyle(phaseColor)
                            Text("Add Grocery Item")
                                .font(.nSubheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Grocery List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showAddGrocery) {
                AddPlanItemSheet(
                    defaultCategory: .grocery,
                    phaseSlug: phaseSlug
                )
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Category Section

    private func categorySection(_ category: String, items: [GroceryItem], customItems: [UserPlanItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category header with phase-tinted background
            Text(category.uppercased())
                .font(.nCaption2)
                .fontWeight(.semibold)
                .tracking(2)
                .foregroundStyle(phaseColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(phaseColor.opacity(0.06))

            // Template items
            ForEach(items, id: \.id) { item in
                groceryRow(item)
                    .contextMenu {
                        Button(role: .destructive) {
                            hideItem(item.id, type: .grocery)
                        } label: {
                            Label("Hide Item", systemImage: "eye.slash")
                        }
                    }
            }

            // Custom items
            ForEach(customItems, id: \.id) { item in
                customGroceryRow(item)
                    .contextMenu {
                        Button(role: .destructive) {
                            item.isActive = false
                            syncService.queueChange(
                                table: "userPlanItems", action: "upsert",
                                data: ["id": item.id, "isActive": false], modelContext: modelContext
                            )
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
            }
        }
    }

    // MARK: - Grocery Row

    private func groceryRow(_ item: GroceryItem) -> some View {
        let isChecked = checkedIds.contains(item.id)

        return Button { toggleItem(item) } label: {
            HStack(spacing: 10) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.sans(18))
                    .foregroundStyle(isChecked ? phaseColor : Color(uiColor: .tertiaryLabel))

                Text(item.name)
                    .font(.nSubheadline)
                    .foregroundStyle(isChecked ? .secondary : .primary)
                    .strikethrough(isChecked)

                if let flag = item.saFlag, !flag.isEmpty {
                    Text(flag)
                        .font(.nCaption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.spice)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.spice.opacity(0.1))
                        .clipShape(Capsule())
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Custom Grocery Row

    private func customGroceryRow(_ item: UserPlanItem) -> some View {
        let isChecked = checkedIds.contains(item.id)

        return Button { toggleCustomItem(item) } label: {
            HStack(spacing: 10) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.sans(18))
                    .foregroundStyle(isChecked ? phaseColor : Color(uiColor: .tertiaryLabel))

                Text(item.title)
                    .font(.nSubheadline)
                    .foregroundStyle(isChecked ? .secondary : .primary)
                    .strikethrough(isChecked)

                Text("CUSTOM")
                    .font(.sans(7))
                    .fontWeight(.bold)
                    .tracking(0.5)
                    .foregroundStyle(phaseColor)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Share Text

    private var shareText: String {
        var text = "Grocery List — \(phase?.name ?? "") Phase\n\n"
        for category in categories {
            let catItems = items.filter { $0.category == category }
            let customCatItems = customGrocery.filter { ($0.groceryCategory ?? "Other") == category }
            if !catItems.isEmpty || !customCatItems.isEmpty {
                text += "\(category):\n"
                for item in catItems {
                    let check = checkedIds.contains(item.id) ? "✓" : "○"
                    text += "  \(check) \(item.name)\n"
                }
                for item in customCatItems {
                    let check = checkedIds.contains(item.id) ? "✓" : "○"
                    text += "  \(check) \(item.title) (custom)\n"
                }
                text += "\n"
            }
        }
        return text
    }

    // MARK: - Actions

    private func toggleItem(_ item: GroceryItem) {
        if let existing = groceryChecks.first(where: { $0.groceryItemId == item.id }) {
            existing.checked.toggle()
            existing.updatedAt = Date()
            syncService.queueChange(
                table: "groceryChecks", action: "upsert",
                data: [
                    "id": existing.id,
                    "groceryItemId": item.id,
                    "checked": existing.checked,
                ],
                modelContext: modelContext
            )
        } else {
            let check = GroceryCheck(groceryItemId: item.id, checked: true)
            modelContext.insert(check)
            syncService.queueChange(
                table: "groceryChecks", action: "upsert",
                data: [
                    "id": check.id,
                    "groceryItemId": item.id,
                    "checked": true,
                ],
                modelContext: modelContext
            )
        }
    }

    private func toggleCustomItem(_ item: UserPlanItem) {
        if let existing = groceryChecks.first(where: { $0.groceryItemId == item.id }) {
            existing.checked.toggle()
            existing.updatedAt = Date()
            syncService.queueChange(
                table: "groceryChecks", action: "upsert",
                data: [
                    "id": existing.id,
                    "groceryItemId": item.id,
                    "checked": existing.checked,
                ],
                modelContext: modelContext
            )
        } else {
            let check = GroceryCheck(groceryItemId: item.id, checked: true)
            modelContext.insert(check)
            syncService.queueChange(
                table: "groceryChecks", action: "upsert",
                data: [
                    "id": check.id,
                    "groceryItemId": item.id,
                    "checked": true,
                ],
                modelContext: modelContext
            )
        }
    }

    private func hideItem(_ itemId: String, type: PlanItemCategory) {
        let hidden = UserItemHidden(itemId: itemId, itemType: type)
        modelContext.insert(hidden)
        syncService.queueChange(
            table: "userItemsHidden", action: "upsert",
            data: ["id": hidden.id, "itemId": itemId], modelContext: modelContext
        )
    }

    private func resetAll() {
        for check in groceryChecks where checkedIds.contains(check.groceryItemId) {
            check.checked = false
            check.updatedAt = Date()
            syncService.queueChange(
                table: "groceryChecks", action: "upsert",
                data: [
                    "id": check.id,
                    "groceryItemId": check.groceryItemId,
                    "checked": false,
                ],
                modelContext: modelContext
            )
        }
    }
}
