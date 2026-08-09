import Foundation

/// Fehler, die vom API-Service geworfen werden.
enum APIError: Error {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError
    case networkError(Error)
}

extension APIError: Equatable {
    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL): return true
        case (.invalidResponse, .invalidResponse): return true
        case (.httpError(let lCode, let lMsg), .httpError(let rCode, let rMsg)):
            return lCode == rCode && lMsg == rMsg
        case (.decodingError, .decodingError): return true
        case (.networkError, .networkError): return true
        default: return false
        }
    }
}

/// Antwort des Auth-Endpoints.
struct AuthResponse: Codable {
    let token: String
    let token_type: String
    let expires_in: Int
    let user: UserDTO
}

/// Benutzer-Daten aus dem Backend.
struct UserDTO: Codable {
    let id: String
    let public_user_id: String
    let account_provider: String
    let display_name: String?
    let created_at: String
}

/// Spiel-Daten fur POST /games.
struct CreateGameRequest: Codable {
    let client_game_id: String
    let reaction_time_ms: Int
    let rating: String
    let accuracy_score: Int
    let combo_multiplier: Double
    let total_score: Int
    let played_at: String
    let virtual_line_count: Double?
    let virtual_distance_meters: Double?
    let metadata: [String: String]?
}

/// Spiel-Daten aus dem Backend.
struct GameDTO: Codable {
    let id: String
    let client_game_id: String
    let reaction_time_ms: Int
    let rating: String
    let accuracy_score: Int
    let combo_multiplier: Double
    let total_score: Int
    let virtual_line_count: Double?
    let virtual_distance_meters: Double?
    let played_at: String
    let created_at: String
    let synced_at: String?
}

/// Paginierte Spiel-Liste.
struct GameListResponse: Codable {
    let data: [GameDTO]
    let pagination: PaginationInfo
}

struct PaginationInfo: Codable {
    let next_cursor: String?
    let has_more: Bool
}

/// Profil-Daten aus dem Backend.
struct ProfileDTO: Codable {
    let id: String
    let public_user_id: String
    let account_provider: String
    let display_name: String?
    let avatar_url: String?
    let flour_track_factor: Double
    let origin_city_name: String?
    let origin_latitude: Double?
    let origin_longitude: Double?
    let created_at: String
    let updated_at: String
}

/// Minimaler Request fur Apple Sign In.
struct AppleAuthRequest: Codable {
    let identity_token: String
    let authorization_code: String
    let guest_token: String?
}

/// Minimaler Request fur Guest Auth.
struct GuestAuthRequest: Codable {
    let display_name: String?
}

/// Thread-sicherer API-Client fur FlourTrack Backend.
actor FlourTrackAPI {
    private let baseURL: URL
    private let urlSession: URLSession

    init(baseURL: URL = URL(string: "http://localhost:8080")!) {
        self.baseURL = baseURL
        self.urlSession = URLSession.shared
    }

    // MARK: - Auth

    /// Erzeugt einen Guest-Account und liefert JWT.
    func createGuest(displayName: String? = nil) async throws -> AuthResponse {
        let request = GuestAuthRequest(display_name: displayName)
        return try await post(path: "/auth/guest", body: request, requiresAuth: false)
    }

    /// Verifiziert Apple Sign In und linked zu Guest oder erstellt neu.
    func signInWithApple(identityToken: String, authorizationCode: String, guestToken: String? = nil) async throws -> AuthResponse {
        let request = AppleAuthRequest(
            identity_token: identityToken,
            authorization_code: authorizationCode,
            guest_token: guestToken
        )
        return try await post(path: "/auth/apple", body: request, requiresAuth: false)
    }

    // MARK: - Games

    /// Speichert ein Spiel idempotent via client_game_id.
    func createGame(_ game: CreateGameRequest) async throws -> GameDTO {
        return try await post(path: "/games", body: game)
    }

    /// Ladt die Spiel-History mit cursor-basierter Paginierung.
    func listGames(cursor: String? = nil, limit: Int = 20) async throws -> GameListResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("/games"), resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = []
        if let cursor = cursor { queryItems.append(URLQueryItem(name: "cursor", value: cursor)) }
        if limit != 20 { queryItems.append(URLQueryItem(name: "limit", value: String(limit))) }
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else { throw APIError.invalidURL }
        return try await get(url: url)
    }

    // MARK: - Profile

    /// Ladt das eigene Profil.
    func fetchProfile() async throws -> ProfileDTO {
        return try await get(path: "/profile/me")
    }

    // MARK: - Private Helpers

    private func get<T: Decodable>(path: String) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw APIError.invalidURL }
        return try await get(url: url)
    }

    private func get<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addAuthHeader(to: &request)
        return try await perform(request)
    }

    private func post<T: Decodable, B: Encodable>(path: String, body: B, requiresAuth: Bool = true) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if requiresAuth { addAuthHeader(to: &request) }

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw APIError.decodingError
        }

        return try await perform(request)
    }

    private func addAuthHeader(to request: inout URLRequest) {
        if let token = KeychainTokenStore.token() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Bei 2xx oder 409 (idempotenter Retry) -> dekodieren
        let status = httpResponse.statusCode
        let isSuccess = (200...299).contains(status) || status == 409

        if !isSuccess {
            let message = try? JSONDecoder().decode(ErrorMessage.self, from: data).message
            throw APIError.httpError(statusCode: status, message: message ?? HTTPURLResponse.localizedString(forStatusCode: status))
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError
        }
    }
}

private struct ErrorMessage: Decodable {
    let message: String
}
