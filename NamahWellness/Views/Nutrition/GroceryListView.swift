import SwiftUI
import SwiftData

struct GroceryListView: View {
    let phaseSlug: String

    @Environment(\.modelContext) private var modelContext
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Progress bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(checkedCount) of \(items.count)")
                        .font(.footnote)
                        .fontWeight(.medium)
                    Spacer()
                    Button("Reset") { resetAll() }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: progress)
                    .tint(PhaseColors.forSlug(phaseSlug).color)
            }

            // Categories
            ForEach(categories, id: \.self) { category in
                let catItems = items.filter { $0.category == category }
                if !catItems.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.uppercased())
                            .font(.caption2)
                            .fontWeight(.medium)
                            .textCase(.uppercase)
                            .tracking(2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)

                        ForEach(catItems, id: \.id) { item in
                            groceryRow(item)
                        }
                    }
                }
            }
        }
    }

    private func groceryRow(_ item: GroceryItem) -> some View {
        let isChecked = checkedIds.contains(item.id)

        return Button { toggleItem(item) } label: {
            HStack(spacing: 10) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isChecked ? PhaseColors.forSlug(phaseSlug).color : Color(uiColor: .tertiaryLabel))

                Text(item.name)
                    .font(.subheadline)
                    .foregroundStyle(isChecked ? .secondary : .primary)
                    .strikethrough(isChecked)

                if let flag = item.saFlag, !flag.isEmpty {
                    Text(flag)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.spice)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.spice.opacity(0.1))
                        .clipShape(Capsule())
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func toggleItem(_ item: GroceryItem) {
        if let existing = groceryChecks.first(where: { $0.groceryItemId == item.id }) {
            existing.checked.toggle()
            existing.updatedAt = Date()
            syncService.queueChange(table: "groceryChecks", action: "upsert",
                                    data: ["id": AnyCodable(existing.id), "groceryItemId": AnyCodable(item.id),
                                           "checked": AnyCodable(existing.checked)],
                                    modelContext: modelContext)
        } else {
            let check = GroceryCheck(groceryItemId: item.id, checked: true)
            modelContext.insert(check)
            syncService.queueChange(table: "groceryChecks", action: "upsert",
                                    data: ["id": AnyCodable(check.id), "groceryItemId": AnyCodable(item.id),
                                           "checked": AnyCodable(true)],
                                    modelContext: modelContext)
        }
    }

    private func resetAll() {
        for check in groceryChecks where checkedIds.contains(check.groceryItemId) {
            check.checked = false
            check.updatedAt = Date()
            syncService.queueChange(table: "groceryChecks", action: "upsert",
                                    data: ["id": AnyCodable(check.id), "groceryItemId": AnyCodable(check.groceryItemId),
                                           "checked": AnyCodable(false)],
                                    modelContext: modelContext)
        }
    }
}
