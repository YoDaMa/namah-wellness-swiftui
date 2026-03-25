import SwiftUI

struct TimeBlockProgressBar: View {
    let completed: Int
    let total: Int
    let streak: Int
    let phaseColor: Color

    @State private var showInfo = false

    private var progress: Double {
        total > 0 ? Double(completed) / Double(total) : 0
    }

    var body: some View {
        Button { showInfo = true } label: {
            HStack(spacing: 10) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(uiColor: .tertiarySystemFill))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(phaseColor)
                            .frame(width: geo.size.width * progress, height: 6)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: progress)
                    }
                }
                .frame(height: 6)

                if streak > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.sans(11))
                            .foregroundStyle(.spice)
                        Text("\(streak)")
                            .font(.nCaption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.spice)
                    }
                }

                Text("\(completed)/\(total)")
                    .font(.nCaption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .alert("Daily Progress", isPresented: $showInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Tracks your meals, supplements, and workouts for today. Complete items by tapping the checkmark next to each one.")
        }
    }
}
