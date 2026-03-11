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
                        .renderingMode(.original)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)

                    Text("Wellness, in rhythm.")
                        .font(.displayItalic(24, relativeTo: .title3))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 48)

                // Fields
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .clipShape(Capsule())

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { signIn() }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .clipShape(Capsule())
                }

                // Error
                if let error = authService.errorMessage {
                    Text(error)
                        .font(.nCaption)
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
                                .font(.nHeadline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .foregroundStyle(Color(uiColor: .systemBackground))
                .background(canSubmit ? Color.primary : Color.secondary)
                .clipShape(Capsule())
                .disabled(!canSubmit)
                .padding(.top, 24)
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(uiColor: .systemBackground))
    }

    private func signIn() {
        guard canSubmit else { return }
        focusedField = nil
        Task {
            await authService.signIn(email: email, password: password)
        }
    }
}
