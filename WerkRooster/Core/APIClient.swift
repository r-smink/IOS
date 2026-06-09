import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case unauthorized
    case server(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Ongeldige URL"
        case .unauthorized:
            return "Sessie verlopen"
        case .server(let message):
            return message
        case .transport(let message):
            return message
        }
    }
}

final class APIClient {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    func login(baseUrl: String, body: LoginRequest) async throws -> LoginResponse {
        try await request(baseUrl: baseUrl, path: "wp-json/roosterplanner/v1/auth/login", method: "POST", token: nil, body: body)
    }

    func refresh(baseUrl: String, body: RefreshRequest) async throws -> LoginResponse {
        try await request(baseUrl: baseUrl, path: "wp-json/roosterplanner/v1/auth/refresh", method: "POST", token: nil, body: body)
    }

    func logout(baseUrl: String, token: String?, body: LogoutRequest) async throws {
        _ = try await requestEmpty(baseUrl: baseUrl, path: "wp-json/roosterplanner/v1/auth/logout", method: "POST", token: token, body: body)
    }

    func me(baseUrl: String, token: String?) async throws -> MeResponse {
        try await request(baseUrl: baseUrl, path: "wp-json/roosterplanner/v1/me", method: "GET", token: token)
    }

    func schedules(baseUrl: String, token: String?, startDate: String, endDate: String) async throws -> [ScheduleItem] {
        try await request(baseUrl: baseUrl, path: "wp-json/roosterplanner/v1/schedules", method: "GET", token: token, query: [
            URLQueryItem(name: "start_date", value: startDate),
            URLQueryItem(name: "end_date", value: endDate)
        ])
    }

    func notifications(baseUrl: String, token: String?) async throws -> [NotificationItem] {
        try await request(baseUrl: baseUrl, path: "wp-json/roosterplanner/v1/notifications", method: "GET", token: token, query: [
            URLQueryItem(name: "limit", value: "50"),
            URLQueryItem(name: "unread_only", value: "0")
        ])
    }

    func markNotificationRead(baseUrl: String, token: String?, id: Int) async throws {
        _ = try await requestEmpty(
            baseUrl: baseUrl,
            path: "wp-json/roosterplanner/v1/notifications/\(id)/read",
            method: "POST",
            token: token,
            body: Optional<String>.none
        )
    }

    func availability(baseUrl: String, token: String?, month: String, locationId: Int) async throws -> AvailabilityResponse {
        try await request(baseUrl: baseUrl, path: "wp-json/roosterplanner/v1/availability", method: "GET", token: token, query: [
            URLQueryItem(name: "month", value: month),
            URLQueryItem(name: "location_id", value: "\(locationId)")
        ])
    }

    func upsertAvailability(baseUrl: String, token: String?, body: AvailabilityUpsertRequest) async throws {
        _ = try await requestEmpty(baseUrl: baseUrl, path: "wp-json/roosterplanner/v1/availability", method: "POST", token: token, body: body)
    }

    func shifts(baseUrl: String, token: String?, locationId: Int) async throws -> [Shift] {
        try await request(baseUrl: baseUrl, path: "wp-json/roosterplanner/v1/shifts", method: "GET", token: token, query: [
            URLQueryItem(name: "location_id", value: "\(locationId)")
        ])
    }

    func sick(baseUrl: String, token: String?, reason: String?) async throws {
        _ = try await requestEmpty(baseUrl: baseUrl, path: "wp-json/roosterplanner/v1/sick", method: "POST", token: token, body: SickReportRequest(reason: reason))
    }

    func registerDevice(baseUrl: String, token: String?, fcmToken: String) async throws {
        _ = try await requestEmpty(
            baseUrl: baseUrl,
            path: "wp-json/roosterplanner/v1/devices",
            method: "POST",
            token: token,
            body: DeviceRegistrationRequest(fcmToken: fcmToken, platform: "ios")
        )
    }

    func chatHistory(baseUrl: String, token: String?, lastId: Int? = nil) async throws -> [ChatMessage] {
        var query: [URLQueryItem] = [URLQueryItem(name: "limit", value: "50")]
        if let lastId {
            query.append(URLQueryItem(name: "last_id", value: "\(lastId)"))
        }
        return try await request(baseUrl: baseUrl, path: "wp-json/roosterplanner/v1/chat", method: "GET", token: token, query: query)
    }

    func sendChat(baseUrl: String, token: String?, text: String) async throws -> ChatMessage {
        try await request(
            baseUrl: baseUrl,
            path: "wp-json/roosterplanner/v1/chat",
            method: "POST",
            token: token,
            body: SendMessageRequest(message: text, locationId: nil, isAnnouncement: 0)
        )
    }

    func streamChat(baseUrl: String, token: String?, lastId: Int, onMessage: @escaping (ChatMessage) -> Void) async {
        guard var components = URLComponents(string: baseUrl.ensureTrailingSlash() + "wp-json/roosterplanner/v1/chat/stream") else {
            return
        }
        components.queryItems = [URLQueryItem(name: "last_id", value: "\(lastId)")]
        guard let url = components.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("WerkRooster-iOS/1.0", forHTTPHeaderField: "User-Agent")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 401 { return }

            for try await line in bytes.lines {
                guard line.hasPrefix("data: ") else { continue }
                let json = String(line.dropFirst(6))
                guard let data = json.data(using: .utf8),
                      let decoded = try? decoder.decode(ChatMessage.self, from: data) else {
                    continue
                }
                onMessage(decoded)
            }
        } catch {
            return
        }
    }

    private func request<T: Decodable, B: Encodable>(
        baseUrl: String,
        path: String,
        method: String,
        token: String?,
        query: [URLQueryItem] = [],
        body: B? = nil
    ) async throws -> T {
        let data = try await requestData(baseUrl: baseUrl, path: path, method: method, token: token, query: query, body: body)
        return try decoder.decode(T.self, from: data)
    }

    private func request<T: Decodable>(
        baseUrl: String,
        path: String,
        method: String,
        token: String?,
        query: [URLQueryItem] = []
    ) async throws -> T {
        let data = try await requestData(baseUrl: baseUrl, path: path, method: method, token: token, query: query, body: Optional<String>.none)
        return try decoder.decode(T.self, from: data)
    }

    private func requestEmpty<B: Encodable>(
        baseUrl: String,
        path: String,
        method: String,
        token: String?,
        body: B? = nil
    ) async throws -> Data {
        try await requestData(baseUrl: baseUrl, path: path, method: method, token: token, body: body)
    }

    private func requestData<B: Encodable>(
        baseUrl: String,
        path: String,
        method: String,
        token: String?,
        query: [URLQueryItem] = [],
        body: B? = nil
    ) async throws -> Data {
        guard var components = URLComponents(string: baseUrl.ensureTrailingSlash() + path) else {
            throw APIError.invalidURL
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("WerkRooster-iOS/1.0", forHTTPHeaderField: "User-Agent")
        print("[DEBUG] Request: \(method) \(url.absoluteString)")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport("Geen geldige serverresponse")
        }

        if http.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard 200..<300 ~= http.statusCode else {
            let bodyString = String(data: data, encoding: .utf8) ?? "<no body>"
            print("[DEBUG] HTTP Error \(http.statusCode) for \(url.absoluteString)")
            print("[DEBUG] Response body: \(bodyString)")
            if let apiError = try? decoder.decode(APIErrorResponse.self, from: data), let message = apiError.message {
                throw APIError.server(message)
            }
            throw APIError.server("HTTP \(http.statusCode): \(bodyString)")
        }

        return data
    }
}

private extension String {
    func ensureTrailingSlash() -> String {
        hasSuffix("/") ? self : self + "/"
    }
}
