import Foundation

protocol AuthServicing {
    func signIn(email: String, password: String) async throws -> Session
    func refreshSession(refreshToken: String) async throws -> Session
    func signUp(email: String, password: String) async throws -> Session?
    func resendConfirmation(email: String) async throws
    func requestPasswordReset(email: String, redirectTo: String) async throws
    func updatePassword(accessToken: String, newPassword: String) async throws
    func verifyRecoveryTokenHash(_ tokenHash: String) async throws -> Session
}

private struct SupabaseSignInBody: Encodable {
    let email: String
    let password: String
}

private struct SupabasePasswordResetBody: Encodable {
    let email: String
    let redirectTo: String

    enum CodingKeys: String, CodingKey {
        case email
        case redirectTo = "redirect_to"
    }
}

private struct SupabaseUpdatePasswordBody: Encodable {
    let password: String
}

private struct SupabaseVerifyRecoveryBody: Encodable {
    let tokenHash: String
    let type: String

    enum CodingKeys: String, CodingKey {
        case tokenHash = "token_hash"
        case type
    }
}

private struct SupabaseRefreshBody: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

private struct SupabaseErrorResponse: Decodable {
    let code: String?
    let error: String?
    let msg: String?
    let message: String?
    let errorDescription: String?
}

final class SupabaseAuthService: AuthServicing {
    private let config: AppConfig
    private let urlSession: URLSession

    init(config: AppConfig, urlSession: URLSession = .shared) {
        self.config = config
        self.urlSession = urlSession
    }

    func signIn(email: String, password: String) async throws -> Session {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let endpoint = config.supabaseURL
            .appending(path: "auth/v1/token")
            .appending(queryItems: [URLQueryItem(name: "grant_type", value: "password")])

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")

        let body = SupabaseSignInBody(email: normalizedEmail, password: password)
        request.httpBody = try JSONEncoder().encode(body)

        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let supabaseError = try? decoder.decode(SupabaseErrorResponse.self, from: data)
                let rawResponse = String(data: data, encoding: .utf8)
                let message = supabaseError?.msg
                    ?? supabaseError?.message
                    ?? supabaseError?.errorDescription
                    ?? supabaseError?.error
                    ?? rawResponse
                    ?? "Ошибка входа. Проверьте данные."
                #if DEBUG
                print("[Auth][DEBUG] signIn failed")
                print("[Auth][DEBUG] email:", normalizedEmail)
                print("[Auth][DEBUG] supabaseURL:", config.supabaseURL.absoluteString)
                print("[Auth][DEBUG] message:", message)
                #endif
                throw APIError.validation(message: message)
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let authResponse = try decoder.decode(SupabaseAuthResponse.self, from: data)
            guard let accessToken = authResponse.accessToken, !accessToken.isEmpty else {
                throw APIError.validation(message: "Сессия не получена.")
            }
            #if DEBUG
            print("[Auth] signIn success for:", authResponse.user.email ?? normalizedEmail)
            print("[Auth] token:", maskToken(accessToken))
            #endif

            return Session(
                accessToken: accessToken,
                refreshToken: authResponse.refreshToken,
                expiresIn: authResponse.expiresIn,
                userEmail: authResponse.user.email ?? normalizedEmail
            )
        } catch {
            #if DEBUG
            print("[Auth] signIn error:", error.localizedDescription)
            print("[Auth][DEBUG] email:", normalizedEmail)
            print("[Auth][DEBUG] supabaseURL:", config.supabaseURL.absoluteString)
            print("[Auth][DEBUG] message:", error.localizedDescription)
            #endif
            throw APIErrorMapper().map(error: error)
        }
    }

    func refreshSession(refreshToken: String) async throws -> Session {
        let endpoint = config.supabaseURL
            .appending(path: "auth/v1/token")
            .appending(queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")])

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(SupabaseRefreshBody(refreshToken: refreshToken))

        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let supabaseError = try? decoder.decode(SupabaseErrorResponse.self, from: data)
                let message = supabaseError?.msg
                    ?? supabaseError?.message
                    ?? supabaseError?.errorDescription
                    ?? supabaseError?.error
                    ?? "Не удалось обновить сессию."
                throw APIErrorMapper().map(statusCode: httpResponse.statusCode, message: message)
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let authResponse = try decoder.decode(SupabaseAuthResponse.self, from: data)
            guard let accessToken = authResponse.accessToken, !accessToken.isEmpty else {
                throw APIError.validation(message: "Не удалось обновить сессию.")
            }
            #if DEBUG
            print("[Auth] refresh success, token:", maskToken(accessToken))
            #endif
            return Session(
                accessToken: accessToken,
                refreshToken: authResponse.refreshToken ?? refreshToken,
                expiresIn: authResponse.expiresIn,
                userEmail: authResponse.user.email ?? ""
            )
        } catch {
            #if DEBUG
            print("[Auth] refresh error:", error.localizedDescription)
            #endif
            throw APIErrorMapper().map(error: error)
        }
    }

    func signUp(email: String, password: String) async throws -> Session? {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let endpoint = config.supabaseURL.appending(path: "auth/v1/signup")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(SupabaseSignInBody(email: normalizedEmail, password: password))

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let supabaseError = try? decoder.decode(SupabaseErrorResponse.self, from: data)
            let raw = String(data: data, encoding: .utf8) ?? "Ошибка регистрации."
            let message = supabaseError?.msg
                ?? supabaseError?.message
                ?? supabaseError?.errorDescription
                ?? supabaseError?.error
                ?? raw
            #if DEBUG
            print("[Auth] signUp HTTP \(http.statusCode):", message)
            #endif
            throw APIError.validation(message: message)
        }
        // GoTrue при «подтвердите email» часто отдаёт 200 с телом вида «пользователь у корня» без access_token и без ключа user — старый Decodable падал и показывал «ошибка данных сервера».
        return Self.parseSignUpSuccess(data: data, fallbackEmail: normalizedEmail)
    }

    /// Разбор успешного signup: полная сессия или ожидание подтверждения почты (без токенов).
    private static func parseSignUpSuccess(data: Data, fallbackEmail: String) -> Session? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let accessToken = (obj["access_token"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let refreshToken = obj["refresh_token"] as? String
        let expiresIn: Int? = {
            if let i = obj["expires_in"] as? Int { return i }
            if let d = obj["expires_in"] as? Double { return Int(d) }
            if let s = obj["expires_in"] as? String, let i = Int(s) { return i }
            return nil
        }()

        func resolvedEmail() -> String {
            if let user = obj["user"] as? [String: Any], let e = user["email"] as? String {
                let t = e.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !t.isEmpty { return t }
            }
            if let e = obj["email"] as? String {
                let t = e.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !t.isEmpty { return t }
            }
            return fallbackEmail
        }

        if let token = accessToken, !token.isEmpty {
            #if DEBUG
            print("[Auth] signUp: session issued for", resolvedEmail())
            #endif
            return Session(
                accessToken: token,
                refreshToken: refreshToken,
                expiresIn: expiresIn,
                userEmail: resolvedEmail()
            )
        }

        #if DEBUG
        print("[Auth] signUp: pending email confirmation (no access_token) for", fallbackEmail)
        #endif
        return nil
    }

    func resendConfirmation(email: String) async throws {
        let endpoint = config.supabaseURL.appending(path: "auth/v1/resend")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let payload: [String: String] = ["type": "signup", "email": normalized]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let supabaseError = try? decoder.decode(SupabaseErrorResponse.self, from: data)
            let raw = String(data: data, encoding: .utf8) ?? ""
            let resolved: String
            if let m = supabaseError?.msg, !m.isEmpty {
                resolved = m
            } else if let m = supabaseError?.message, !m.isEmpty {
                resolved = m
            } else if let m = supabaseError?.errorDescription, !m.isEmpty {
                resolved = m
            } else if let m = supabaseError?.error, !m.isEmpty {
                resolved = m
            } else if !raw.isEmpty {
                resolved = raw
            } else {
                resolved = "Не удалось отправить письмо повторно."
            }
            throw APIError.validation(message: resolved)
        }
    }

    func requestPasswordReset(email: String, redirectTo: String) async throws {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedEmail.isEmpty else {
            throw APIError.validation(message: "Введите email")
        }
        let endpoint = config.supabaseURL.appending(path: "auth/v1/recover")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(SupabasePasswordResetBody(email: normalizedEmail, redirectTo: redirectTo))

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            let raw = String(data: data, encoding: .utf8) ?? "Не удалось отправить письмо для восстановления."
            throw APIError.validation(message: raw)
        }
    }

    func updatePassword(accessToken: String, newPassword: String) async throws {
        let endpoint = config.supabaseURL.appending(path: "auth/v1/user")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(SupabaseUpdatePasswordBody(password: newPassword))

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            let raw = String(data: data, encoding: .utf8) ?? "Не удалось обновить пароль."
            throw APIError.validation(message: raw)
        }
    }

    func verifyRecoveryTokenHash(_ tokenHash: String) async throws -> Session {
        let endpoint = config.supabaseURL.appending(path: "auth/v1/verify")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(SupabaseVerifyRecoveryBody(tokenHash: tokenHash, type: "recovery"))

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            let raw = String(data: data, encoding: .utf8) ?? "Ссылка восстановления недействительна."
            throw APIError.validation(message: raw)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let authResponse = try decoder.decode(SupabaseAuthResponse.self, from: data)
        guard let accessToken = authResponse.accessToken, !accessToken.isEmpty else {
            throw APIError.validation(message: "Ссылка восстановления недействительна.")
        }
        return Session(
            accessToken: accessToken,
            refreshToken: authResponse.refreshToken,
            expiresIn: authResponse.expiresIn,
            userEmail: authResponse.user.email ?? ""
        )
    }

    private func maskToken(_ token: String) -> String {
        let prefix = token.prefix(10)
        let suffix = token.suffix(6)
        return "\(prefix)...\(suffix)"
    }
}
