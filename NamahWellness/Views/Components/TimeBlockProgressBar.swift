import SwiftUI

struct TimeBlockProgressBar: View {
    let completed: Int
    let total: Int
    let streak: Int
    let phaseColor: Color

    @State private var showInfo = false
    @State private var glowPhase: CGFloat = 0

    private var progress: Double {
        total > 0 ? Double(completed) / Double(total) : 0
    }

    private var allDone: Bool {
        total > 0 && completed >= total
    }

    private var auroraColors: [Color] {
        [.pink, .purple, .indigo, .blue, .cyan, .mint, .green, .yellow, .orange, .red, .pink, .purple]
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
            .background {
                if allDone {
                    // Soft aurora glow — large blur, low opacity for dreamy effect
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            AngularGradient(
                                colors: auroraColors,
                                center: .center,
                                angle: .degrees(glowPhase * 360)
                            )
                        )
                        .blur(radius: 24)
                        .opacity(0.45)
                        .scaleEffect(1.15)
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .onAppear { startGlowIfNeeded() }
        .onChange(of: allDone) { startGlowIfNeeded() }
        .alert("Daily Progress", isPresented: $showInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Tracks your meals, supplements, and workouts for today. Complete items by tapping the checkmark next to each one.")
        }
    }

    private func startGlowIfNeeded() {
        if allDone {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                glowPhase = 1
            }
        } else {
            withAnimation(.easeOut(duration: 0.3)) {
                glowPhase = 0
            }
        }
    }
}
