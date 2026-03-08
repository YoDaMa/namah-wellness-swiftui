import SwiftUI

struct AccountSettingsView: View {
    var body: some View {
        Form {
            Section("Account") {
                LabeledContent("Name", value: "User")
                LabeledContent("Email", value: "user@example.com")
            }

            Section {
                HStack {
                    Spacer()
                    Text("Namah Wellness v1.0")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
