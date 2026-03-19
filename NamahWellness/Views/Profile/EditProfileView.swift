import SwiftUI
import SwiftData

struct EditProfileView: View {
    let cycleService: CycleService

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var profiles: [UserProfile]

    @State private var cycleLength = 28
    @State private var periodLength = 5
    @State private var hasAppeared = false

    private var profile: UserProfile {
        if let p = profiles.first { return p }
        let p = UserProfile()
        modelContext.insert(p)
        return p
    }

    var body: some View {
        Form {
            // Cycle settings
            Section("Cycle") {
                Picker("Cycle Length", selection: $cycleLength) {
                    ForEach(20...40, id: \.self) { day in
                        Text("\(day) days").tag(day)
                    }
                }
                .font(.nSubheadline)

                Picker("Period Length", selection: $periodLength) {
                    ForEach(2...10, id: \.self) { day in
                        Text("\(day) days").tag(day)
                    }
                }
                .font(.nSubheadline)
            }

        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
            }
        }
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            let p = profile
            cycleLength = p.cycleLengthOverride ?? cycleService.cycleStats.avgCycleLength
            periodLength = p.periodLengthOverride ?? cycleService.cycleStats.avgPeriodLength
        }
    }

    private func save() {
        profile.cycleLengthOverride = cycleLength
        profile.periodLengthOverride = periodLength
        try? modelContext.save()
        dismiss()
    }
}
