import SwiftUI

struct PlanView: View {
    let cycleService: CycleService

    var body: some View {
        NavigationStack {
            Text("Plan")
                .navigationTitle("Plan")
        }
    }
}
