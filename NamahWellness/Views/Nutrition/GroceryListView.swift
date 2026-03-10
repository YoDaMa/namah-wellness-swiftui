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

    private var phase: Phase? { phases.first { $0.slug == phaseSlug } }

    private var items: [GroceryItem] {
        guard let p = phase else { return [] }
        return groceryItems.filter { $0.phaseId == p.id }
    }

    private var checkedIds: Set<String> {
        Set(groceryChecks.filter { $0.checked }.map(\.groceryItemId))
    }

    private var checkedCount: Int { items.filter { checkedIds.contains($0.id) }.count }
    private var progress: Double { items.isEmpty ? 0 : Double(checkedCount) / Double(items.count) }

    private let categories = ["Protein", "Produce", "Pantry / Grains"]

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
                            Text("\(checkedCount) of \(items.count) items")
                                .font(.nFootnote)
                                .fontWeight(.medium)
                            Spacer()
                        }

                        ProgressView(value: progress)
                            .tint(phaseColor)
                    }
                    .padding(16)
                    .background(phaseColors.soft)

                    // Category sections
                    ForEach(categories, id: \.self) { category in
                        let catItems = items.filter { $0.category == category }
                        if !catItems.isEmpty {
                            categorySection(category, items: catItems)
                        }
                    }
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
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Category Section

    private func categorySection(_ category: String, items: [GroceryItem]) -> some View {
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

            // Items
            ForEach(items, id: \.id) { item in
                groceryRow(item)
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

    // MARK: - Share Text

    private var shareText: String {
        var text = "Grocery List — \(phase?.name ?? "") Phase\n\n"
        for category in categories {
            let catItems = items.filter { $0.category == category }
            if !catItems.isEmpty {
                text += "\(category):\n"
                for item in catItems {
                    let check = checkedIds.contains(item.id) ? "✓" : "○"
                    text += "  \(check) \(item.name)\n"
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
