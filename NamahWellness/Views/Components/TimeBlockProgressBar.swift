import SwiftUI

struct TimeBlockProgressBar: View {
    let completed: Int
    let total: Int
    let streak: Int
    let phaseColor: Color

    private var progress: Double {
        total > 0 ? Double(completed) / Double(total) : 0
    }

    private var isAllDone: Bool {
        total > 0 && completed >= total
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                if isAllDone {
                    Text("All done for today")
                        .font(.nSubheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(phaseColor)
                } else {
                    Text("\(completed) of \(total)")
                        .font(.nSubheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text("completed")
                        .font(.nCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if streak > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.sans(11))
                            .foregroundStyle(.spice)
                        Text("\(streak) day streak")
                            .font(.nCaption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.spice)
                    }
                }
            }

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
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
