import Foundation

struct ErrorEnvelope: Decodable {
    let ok: Bool?
    let error: String?
    let message: String?
}

private struct DataEnvelope<T: Decodable>: Decodable {
    let data: T
}

final class APIClient {
    private struct EmptyBody: Encodable {}
    private let requestTimeout: TimeInterval = 30

    private let config: AppConfig
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let errorMapper: APIErrorMapper
    private var tokenProvider: (() -> String?)?
    private var tokenRefresher: (() async -> Bool)?
    private var unauthorizedHandler: (() -> Void)?

    init(
        config: AppConfig,
        session: URLSession = .shared,
        errorMapper: APIErrorMapper = APIErrorMapper()
    ) {
        self.config = config
        self.session = session
        self.errorMapper = errorMapper

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func setTokenProvider(_ provider: @escaping (() -> String?)) {
        tokenProvider = provider
    }

    func setTokenRefresher(_ refresher: @escaping (() async -> Bool)) {
        tokenRefresher = refresher
    }

    func setUnauthorizedHandler(_ handler: @escaping (() -> Void)) {
        unauthorizedHandler = handler
    }

    func request<T: Decodable, Body: Encodable>(
        _ endpoint: APIEndpoint,
        body: Body? = nil
    ) async throws -> T {
        return try await performRequest(endpoint: endpoint, body: body, retryOnUnauthorized: true)
    }

    func request<T: Decodable>(
        _ endpoint: APIEndpoint
    ) async throws -> T {
        let emptyBody: EmptyBody? = nil
        return try await request(endpoint, body: emptyBody)
    }

    private func buildRequest<Body: Encodable>(
        endpoint: APIEndpoint,
        body: Body?
    ) throws -> URLRequest {
        guard var components = URLComponents(url: config.apiBaseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }

        components.path = endpoint.path
        components.queryItems = endpoint.queryItems.isEmpty ? nil : endpoint.queryItems

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if endpoint.method != .GET {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if let token = tokenProvider?(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        return request
    }

    private func performRequest<T: Decodable, Body: Encodable>(
        endpoint: APIEndpoint,
        body: Body?,
        retryOnUnauthorized: Bool
    ) async throws -> T {
        let request = try buildRequest(endpoint: endpoint, body: body)
        debugLogRequest(request)

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            debugLogResponse(statusCode: httpResponse.statusCode, data: data, url: request.url?.absoluteString)

            if (200...299).contains(httpResponse.statusCode) {
                do {
                    if let direct = try? decoder.decode(T.self, from: data) {
                        return direct
                    }
                    if let wrapped = try? decoder.decode(DataEnvelope<T>.self, from: data) {
                        return wrapped.data
                    }
                    throw APIError.decodingFailed
                } catch {
                    throw APIErrorMapper().map(error: error)
                }
            }

            if httpResponse.statusCode == 401, retryOnUnauthorized {
                if let tokenRefresher, await tokenRefresher() {
                    return try await performRequest(endpoint: endpoint, body: body, retryOnUnauthorized: false)
                }
                unauthorizedHandler?()
                throw APIError.unauthorized
            }

            if httpResponse.statusCode == 401, !retryOnUnauthorized {
                unauthorizedHandler?()
                throw APIError.unauthorized
            }

            let serverMessage = try? decoder.decode(ErrorEnvelope.self, from: data)
            let mapped = errorMapper.map(statusCode: httpResponse.statusCode, message: serverMessage?.message ?? serverMessage?.error)
            throw mapped
        } catch {
            let mapped = errorMapper.map(error: error)
            throw mapped
        }
    }

    private func debugLogRequest(_ request: URLRequest) {
        #if DEBUG
        let url = request.url?.absoluteString ?? "nil"
        let method = request.httpMethod ?? "GET"
        let authHeader = request.value(forHTTPHeaderField: "Authorization") ?? ""
        let maskedAuth = maskAuthorizationHeader(authHeader)
        print("[API] Request: \(method) \(url)")
        print("[API] Authorization: \(maskedAuth)")
        #endif
    }

    private func debugLogResponse(statusCode: Int, data: Data, url: String?) {
        #if DEBUG
        let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
        print("[API] Status: \(statusCode)")
        print("[API] Body: \(body)")
        if !(200...299).contains(statusCode) {
            print("[API][Failed] endpoint:", url ?? "nil", "status:", statusCode)
        }
        #endif
    }

    private func maskAuthorizationHeader(_ value: String) -> String {
        guard value.hasPrefix("Bearer ") else { return value }
        let token = String(value.dropFirst("Bearer ".count))
        let prefix = token.prefix(10)
        let suffix = token.suffix(6)
        return "Bearer \(prefix)...\(suffix)"
    }
}
