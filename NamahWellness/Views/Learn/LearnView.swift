import SwiftUI

struct LearnView: View {
    let cycleService: CycleService

    var body: some View {
        NavigationStack {
            Text("Learn")
                .navigationTitle("Learn")
        }
    }
}
