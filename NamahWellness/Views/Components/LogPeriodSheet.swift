import SwiftUI
import SwiftData

struct LogPeriodSheet: View {
    let cycleLogManager: CycleLogManager
    @Binding var isPresented: Bool

    @State private var selectedDate = Date()
    @State private var showCorrectionAlert = false
    @State private var correctionExistingDate = ""
    @State private var correctionNewDate = ""

    private let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                    .font(.display(20, relativeTo: .title3))

                DatePicker("", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical)

                Button {
                    handleLog()
                } label: {
                    Text("Log Period Start")
                        .font(.nHeadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.primary)
            }
            .padding()
            .navigationTitle("Log Period Start")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
            .alert("Update Period Start?", isPresented: $showCorrectionAlert) {
                Button("Update") {
                    cycleLogManager.confirmCorrection()
                    isPresented = false
                }
                Button("Cancel", role: .cancel) {
                    cycleLogManager.cancelCorrection()
                }
            } message: {
                Text("Update your period start from \(correctionExistingDate) to \(correctionNewDate)?")
            }
        }
        .presentationDetents([.large])
    }

    private func handleLog() {
        let result = cycleLogManager.logPeriod(date: selectedDate)
        switch result {
        case .success, .duplicate, .futureDate:
            isPresented = false
        case .correctionNeeded(let existing, let new):
            correctionExistingDate = formatForDisplay(existing)
            correctionNewDate = formatForDisplay(new)
            showCorrectionAlert = true
        }
    }

    private func formatForDisplay(_ dateStr: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        guard let date = f.date(from: dateStr) else { return dateStr }
        return displayFormatter.string(from: date)
    }
}
