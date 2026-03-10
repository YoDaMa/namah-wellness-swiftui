import SwiftUI
import SwiftData

struct ProfileCardView: View {
    let cycleService: CycleService

    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService

    private var profile: UserProfile {
        profiles.first ?? UserProfile()
    }

    private var displayName: String {
        let name = profile.name.isEmpty
            ? (authService.userName ?? "")
            : profile.name
        return name.isEmpty ? "Your Name" : name
    }

    private var initials: String {
        let parts = displayName.split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
        return parts.isEmpty ? "?" : parts
    }

    private var phaseSlug: String {
        cycleService.currentPhase?.phaseSlug ?? "follicular"
    }

    private var phaseColors: PhaseColors {
        PhaseColors.forSlug(phaseSlug)
    }

    var body: some View {
        NavigationLink {
            EditProfileView(cycleService: cycleService)
        } label: {
            VStack(spacing: 12) {
                // Initials avatar
                Text(initials)
                    .font(.display(24, relativeTo: .title))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(phaseColors.color))

                // Name
                Text(displayName)
                    .font(.display(20, relativeTo: .title3))
                    .foregroundStyle(.primary)

                // Stats
                Text("\(cycleService.cycleStats.avgCycleLength) day cycle · \(cycleService.cycleStats.avgPeriodLength) day period")
                    .font(.nCaption)
                    .foregroundStyle(.secondary)

                // Edit link
                HStack {
                    Spacer()
                    Text("Edit")
                        .font(.nCaption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(phaseColors.soft)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
