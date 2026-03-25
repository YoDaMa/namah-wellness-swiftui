import SwiftUI
import SwiftData

struct BrowseSupplementsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncService.self) private var syncService

    @Query private var definitions: [SupplementDefinition]
    @Query private var userSupplements: [UserSupplement]

    @State private var searchText = ""

    private var filteredDefinitions: [SupplementDefinition] {
        if searchText.isEmpty { return definitions }
        let q = searchText.lowercased()
        return definitions.filter {
            $0.name.lowercased().contains(q) || $0.category.lowercased().contains(q)
        }
    }

    private var activeSupplementIds: Set<String> {
        Set(userSupplements.filter(\.isActive).compactMap(\.supplementId))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        AddCustomSupplementView()
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
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func browseRow(_ def: SupplementDefinition) -> some View {
        let inRegimen = activeSupplementIds.contains(def.id)

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(def.name)
                    .font(.nSubheadline)
                    .fontWeight(.medium)
                HStack(spacing: 6) {
                    if let brand = def.brand, !brand.isEmpty {
                        Text(brand)
                            .font(.nCaption)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(def.servingSize) \(def.servingUnit)")
                        .font(.nCaption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if inRegimen {
                Image(systemName: "checkmark")
                    .foregroundStyle(.phaseF)
            } else {
                Button("Add") { addToRegimen(def) }
                    .font(.nCaption)
                    .fontWeight(.medium)
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
                    .controlSize(.small)
            }
        }
    }

    private func addToRegimen(_ def: SupplementDefinition) {
        let sup = UserSupplement(
            supplementId: def.id, dosage: Double(def.servingSize),
            frequency: "daily", timeOfDay: "morning"
        )
        modelContext.insert(sup)
        syncService.queueChange(
            table: "userSupplements", action: "upsert",
            data: [
                "id": sup.id, "supplementId": def.id,
                "dosage": sup.dosage, "frequency": "daily",
                "timeOfDay": "morning", "isActive": true,
            ],
            modelContext: modelContext
        )
    }
}
