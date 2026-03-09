import Foundation
import Observation

// MARK: - AuthService

@Observable
final class AuthService {

    // MARK: - Keychain Keys

    private enum Keys {
        static let authToken = "authToken"
        static let userId = "userId"
        static let userName = "userName"
        static let userEmail = "userEmail"
    }

    // MARK: - Published State

    var isAuthenticated: Bool = false
    var userId: String?
    var userName: String?
    var userEmail: String?
    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Computed

    var token: String? {
        KeychainHelper.loadString(for: Keys.authToken)
    }

    // MARK: - Init

    init() {
        if let savedToken = KeychainHelper.loadString(for: Keys.authToken), !savedToken.isEmpty {
            isAuthenticated = true
            userId = KeychainHelper.loadString(for: Keys.userId)
            userName = KeychainHelper.loadString(for: Keys.userName)
            userEmail = KeychainHelper.loadString(for: Keys.userEmail)
        }
    }

    // MARK: - Sign In

    @MainActor
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        guard let url = URL(string: "https://namah.yosephmaguire.com/api/auth/sign-in/email") else {
            errorMessage = "Invalid URL"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = ["email": email, "password": password]

        do {
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Invalid response"
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    errorMessage = errorResponse.message ?? "Sign in failed"
                } else {
                    errorMessage = "Sign in failed with status \(httpResponse.statusCode)"
                }
                return
            }

            let signInResponse = try JSONDecoder().decode(SignInResponse.self, from: data)

            // Save to Keychain
            KeychainHelper.saveString(signInResponse.token, for: Keys.authToken)
            KeychainHelper.saveString(signInResponse.user.id, for: Keys.userId)
            KeychainHelper.saveString(signInResponse.user.name, for: Keys.userName)
            KeychainHelper.saveString(signInResponse.user.email, for: Keys.userEmail)

            // Update state
            isAuthenticated = true
            userId = signInResponse.user.id
            userName = signInResponse.user.name
            userEmail = signInResponse.user.email
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign Out

    func signOut() {
        KeychainHelper.delete(for: Keys.authToken)
        KeychainHelper.delete(for: Keys.userId)
        KeychainHelper.delete(for: Keys.userName)
        KeychainHelper.delete(for: Keys.userEmail)

        isAuthenticated = false
        userId = nil
        userName = nil
        userEmail = nil
        errorMessage = nil
    }

    // MARK: - Handle Unauthorized

    func handleUnauthorized() {
        signOut()
    }
}

// MARK: - Response Types

private extension AuthService {

    struct SignInResponse: Decodable {
        let token: String
        let user: SignInUser
    }

    struct SignInUser: Decodable {
        let id: String
        let name: String
        let email: String
    }

    struct ErrorResponse: Decodable {
        let message: String?
    }
}
