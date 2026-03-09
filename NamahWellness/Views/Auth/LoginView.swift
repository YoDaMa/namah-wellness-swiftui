import SwiftUI

struct LoginView: View {
    let authService: AuthService

    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && !authService.isLoading
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 80)

                // Logo + tagline
                VStack(spacing: 16) {
                    Image("Logo")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 88, height: 88)
                        .foregroundStyle(.primary)

                    Text("Wellness, in rhythm")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 48)

                // Fields
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                        TextField("you@example.com", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                        SecureField("Enter your password", text: $password)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { signIn() }
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                // Error
                if let error = authService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 12)
                }

                // Sign in button
                Button(action: signIn) {
                    Group {
                        if authService.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Sign In")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                }
                .foregroundStyle(.white)
                .background(canSubmit ? Color.primary : Color.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(!canSubmit)
                .padding(.top, 24)
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func signIn() {
        guard canSubmit else { return }
        focusedField = nil
        Task {
            await authService.signIn(email: email, password: password)
        }
    }
}
