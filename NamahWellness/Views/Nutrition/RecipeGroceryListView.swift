import SwiftUI

/// Shows aggregated ingredients from all phase meals as a combined grocery list.
struct RecipeGroceryListView: View {
    let ingredients: [(name: String, quantities: [String])]
    let phaseSlug: String
    let phaseColor: Color

    @Environment(\.dismiss) private var dismiss

    private var shareText: String {
        let phase = phaseSlug.capitalized
        var lines = ["\(phase) Phase — Recipe Groceries", ""]
        for ing in ingredients {
            if ing.quantities.isEmpty {
                lines.append("☐ \(ing.name)")
            } else {
                let qtys = ing.quantities.joined(separator: ", ")
                lines.append("☐ \(ing.name) (\(qtys))")
            }
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "basket")
                                .font(.sans(18))
                                .foregroundStyle(phaseColor)
                            Text("Recipe Groceries")
                                .font(.nSubheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(phaseColor)
                        }

                        Text("\(ingredients.count) unique ingredients across all \(phaseSlug.capitalized) phase meals")
                            .font(.nCaption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(phaseColor.opacity(0.06))

                    // Ingredient list
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(ingredients.enumerated()), id: \.offset) { _, ing in
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(phaseColor.opacity(0.3))
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 7)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ing.name)
                                        .font(.sans(14))
                                        .fontWeight(.medium)

                                    if !ing.quantities.isEmpty {
                                        Text(ing.quantities.joined(separator: " + "))
                                            .font(.nCaption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)

                            if ing.name != ingredients.last?.name {
                                Divider().padding(.leading, 30)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Recipe Groceries")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
