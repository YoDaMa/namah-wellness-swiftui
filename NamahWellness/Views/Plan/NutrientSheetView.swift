import SwiftUI
import SwiftData

struct NutrientSheetView: View {
    let phaseSlug: String

    @Environment(\.dismiss) private var dismiss
    @Query private var phases: [Phase]
    @Query private var phaseNutrients: [PhaseNutrient]

    private var phase: Phase? { phases.first { $0.slug == phaseSlug } }
    private var colors: PhaseColors { PhaseColors.forSlug(phaseSlug) }

    private var nutrients: [PhaseNutrient] {
        guard let id = phase?.id else { return [] }
        return phaseNutrients.filter { $0.phaseId == id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FlowLayout(spacing: 8) {
                        ForEach(nutrients, id: \.id) { nut in
                            HStack(spacing: 6) {
                                Text(NamahEmoji.forNutrient(nut.label))
                                Text(nut.label)
                                    .font(.nCaption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(colors.soft)
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding()
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: 0)
                    .background(colors.soft)
            }
            .navigationTitle("Key Nutrients")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
