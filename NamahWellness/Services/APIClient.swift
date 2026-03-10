import Foundation

// MARK: - APIError

enum APIError: Error, LocalizedError {
    case unauthorized
    case networkError(Error)
    case serverError(Int, String?)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Session expired. Please sign in again."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return message ?? "Server error (\(code))"
        case .decodingError(let error):
            return "Failed to process response: \(error.localizedDescription)"
        }
    }
}

// MARK: - APIClient

final class APIClient {

    static let shared = APIClient()

    private let baseURL = "https://namah.yosephmaguire.com"
    private let session = URLSession.shared

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private let encoder = JSONEncoder()

    private init() {}

    // MARK: - Public Methods

    func get<T: Decodable>(path: String) async throws -> T {
        let request = try makeRequest(path: path, method: "GET")
        return try await perform(request)
    }

    func post<T: Decodable>(path: String, body: some Encodable) async throws -> T {
        var request = try makeRequest(path: path, method: "POST")
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await perform(request)
    }

    func postRaw(path: String, body: Data) async throws {
        var request = try makeRequest(path: path, method: "POST")
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = try? decoder.decode(ErrorBody.self, from: data).message
            throw APIError.serverError(httpResponse.statusCode, message)
        }
    }

    func patch<T: Decodable>(path: String, body: some Encodable) async throws -> T {
        var request = try makeRequest(path: path, method: "PATCH")
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await perform(request)
    }

    // MARK: - Private

    private func makeRequest(path: String, method: String) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.networkError(
                URLError(.badURL, userInfo: [NSLocalizedDescriptionKey: "Invalid path: \(path)"])
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        if let token = KeychainHelper.loadString(for: "authToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(
                URLError(.badServerResponse)
            )
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = try? decoder.decode(ErrorBody.self, from: data).message
            throw APIError.serverError(httpResponse.statusCode, message)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}

// MARK: - Private Types

private extension APIClient {
    struct ErrorBody: Decodable {
        let message: String?
    }

}
