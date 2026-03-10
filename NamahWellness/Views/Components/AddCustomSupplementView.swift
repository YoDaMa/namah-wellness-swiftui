import SwiftUI
import SwiftData

struct AddCustomSupplementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncService.self) private var syncService

    @State private var name = ""
    @State private var brand = ""
    @State private var category = "Vitamins"
    @State private var servingSize = "1"
    @State private var servingUnit = "capsule"
    @State private var addToRegimen = true

    private let categories = ["Vitamins", "Minerals", "Omega / Fatty Acids", "Herbal", "Probiotics", "Amino Acids", "Other"]
    private let units = ["capsule", "tablet", "softgel", "scoop", "ml", "drops"]

    var body: some View {
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

    private func save() {
        let def = SupplementDefinition(
            name: name, brand: brand.isEmpty ? nil : brand,
            category: category, servingSize: Int(servingSize) ?? 1,
            servingUnit: servingUnit, isCustom: true
        )
        modelContext.insert(def)

        if addToRegimen {
            let sup = UserSupplement(
                supplementId: def.id, dosage: Double(Int(servingSize) ?? 1),
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
        dismiss()
    }
}
