import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    let session: WorkoutSession?
    let customItem: Habit?
    let dayFocus: String
    let phaseColor: Color
    let coreExercises: [CoreExercise]

    @Environment(\.dismiss) private var dismiss

    private var title: String {
        if let session { return session.title.replacingOccurrences(of: ".$", with: "", options: .regularExpression) }
        if let custom = customItem { return custom.title }
        return "Workout"
    }

    private var description: String? {
        if let session { return session.sessionDescription }
        if let custom = customItem { return custom.subtitle }
        return nil
    }

    private var timeSlot: String? {
        if let session { return session.timeSlot }
        if let custom = customItem { return custom.time }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        if let time = timeSlot {
                            Text(time.uppercased())
                                .font(.nCaption2)
                                .fontWeight(.medium)
                                .foregroundStyle(phaseColor)
                        }
                        if !dayFocus.isEmpty {
                            if timeSlot != nil {
                                Text("·").foregroundStyle(.tertiary)
                            }
                            Text(dayFocus.uppercased())
                                .font(.nCaption2)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(title)
                        .font(.display(22))
                        .foregroundStyle(.primary)

                    if let desc = description, !desc.isEmpty {
                        Text(desc)
                            .font(.prose(13, relativeTo: .footnote))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if customItem != nil {
                        if let dur = customItem?.duration {
                            Text(dur)
                                .font(.nCaption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(phaseColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: NamahRadius.medium))

                // Core Protocol Section (only if exercises exist)
                if !coreExercises.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CORE PROTOCOL")
                            .namahLabel()

                        VStack(spacing: 0) {
                            ForEach(Array(coreExercises.enumerated()), id: \.element.id) { index, exercise in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(exercise.name)
                                            .font(.nSubheadline)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text(exercise.sets)
                                            .font(.nCaption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(exercise.exerciseDescription)
                                        .font(.nCaption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(14)
                                if index < coreExercises.count - 1 {
                                    Divider().padding(.leading, 14)
                                }
                            }
                        }
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: NamahRadius.medium))
                    }
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.black, .white)
                }
            }
        }
    }
}
