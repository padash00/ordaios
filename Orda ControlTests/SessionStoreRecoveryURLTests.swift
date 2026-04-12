import XCTest
@testable import Orda_Control

@MainActor
final class SessionStoreRecoveryURLTests: XCTestCase {
    func testConsumeIncomingURLWithAccessTokenSetsRecoveryState() async {
        let auth = RecoveryAuthService()
        let store = makeStore(auth: auth)

        let url = URL(string: "orda-control://auth/reset-password#access_token=abc123&type=recovery")!
        store.consumeIncomingURL(url)

        XCTAssertEqual(store.passwordResetAccessToken, "abc123")
        XCTAssertEqual(store.authMessage, "Введите новый пароль.")
        XCTAssertFalse(store.isRecoveringPasswordLink)
    }

    func testConsumeIncomingURLWithTokenHashVerifiesAndSetsRecoveryState() async {
        let auth = RecoveryAuthService()
        auth.verifiedSession = Session(
            accessToken: "verified-token",
            refreshToken: nil,
            expiresIn: 3600,
            userEmail: "u@test.com"
        )
        let store = makeStore(auth: auth)

        let url = URL(string: "orda-control://auth/reset-password?token_hash=hash_1&type=recovery")!
        store.consumeIncomingURL(url)

        await waitUntil("token hash verification done") {
            store.passwordResetAccessToken == "verified-token"
        }

        XCTAssertEqual(auth.lastVerifiedTokenHash, "hash_1")
        XCTAssertEqual(store.authMessage, "Введите новый пароль.")
        XCTAssertFalse(store.isRecoveringPasswordLink)
    }

    func testConsumeIncomingURLWithInvalidTokenHashShowsExpiryMessage() async {
        let auth = RecoveryAuthService()
        auth.verifyError = APIError.validation(message: "bad hash")
        let store = makeStore(auth: auth)

        let url = URL(string: "orda-control://auth/reset-password?token_hash=expired&type=recovery")!
        store.consumeIncomingURL(url)

        await waitUntil("invalid hash handled") {
            store.authMessage?.contains("недействительна") == true
        }

        XCTAssertNil(store.passwordResetAccessToken)
        XCTAssertFalse(store.isRecoveringPasswordLink)
    }

    func testConsumeIncomingURLIgnoresNonRecoveryLinks() {
        let auth = RecoveryAuthService()
        let store = makeStore(auth: auth)

        let url = URL(string: "orda-control://some/other/path?foo=bar")!
        store.consumeIncomingURL(url)

        XCTAssertNil(store.passwordResetAccessToken)
        XCTAssertNil(store.authMessage)
    }

    /// Supabase email confirmation: fragment has `access_token` + `type=signup` (not password recovery).
    func testConsumeIncomingURLWithSignupAccessTokenOpensSessionAndRegistration() async {
        let auth = RecoveryAuthService()
        let store = makeStore(auth: auth, verifier: RecoveryVerifierNoAccess())
        // Minimal JWT shape: three segments; payload decodes to `{"email":"signup@test.com"}`.
        let token = "h.eyJlbWFpbCI6InNpZ251cEB0ZXN0LmNvbSJ9.sig"
        let url = URL(string: "orda-control://auth/callback#access_token=\(token)&type=signup")!
        store.consumeIncomingURL(url)

        await waitUntil("bootstrap after signup deep link") {
            if case .registrationDetails = store.onboardingState { return true }
            return store.onboardingState == .app
        }

        XCTAssertEqual(store.session?.accessToken, token)
        XCTAssertEqual(store.session?.userEmail, "signup@test.com")
        XCTAssertEqual(store.onboardingState, .registrationDetails)
        XCTAssertNil(store.passwordResetAccessToken)
    }

    private func makeStore(auth: RecoveryAuthService, verifier: BackendSessionVerifying = RecoveryVerifier()) -> SessionStore {
        SessionStore(
            apiClient: APIClient(config: .testRecovery),
            authService: auth,
            backendSessionVerifier: verifier,
            registrationService: RecoveryRegistrationService(),
            keychainStorage: RecoveryKeychain()
        )
    }

    private func waitUntil(_ description: String, timeout: TimeInterval = 1.0, condition: @escaping () -> Bool) async {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Timeout waiting: \(description)")
    }
}

private extension AppConfig {
    static var testRecovery: AppConfig {
        AppConfig(
            environment: .development,
            apiBaseURL: URL(string: "https://www.ordaops.kz")!,
            supabaseURL: URL(string: "https://example.supabase.co")!,
            supabaseAnonKey: "test-key",
            passwordResetRedirectURL: "orda-control://auth/reset-password"
        )
    }
}

private final class RecoveryAuthService: AuthServicing {
    var verifiedSession: Session?
    var verifyError: Error?
    var lastVerifiedTokenHash: String?

    func signIn(email: String, password: String) async throws -> Session {
        Session(accessToken: "token", refreshToken: "refresh", expiresIn: 3600, userEmail: email)
    }

    func refreshSession(refreshToken: String) async throws -> Session {
        Session(accessToken: "token2", refreshToken: refreshToken, expiresIn: 3600, userEmail: "user@test.com")
    }

    func signUp(email: String, password: String) async throws -> Session? { nil }
    func resendConfirmation(email: String) async throws {}
    func requestPasswordReset(email: String, redirectTo: String) async throws {}
    func updatePassword(accessToken: String, newPassword: String) async throws {}

    func verifyRecoveryTokenHash(_ tokenHash: String) async throws -> Session {
        lastVerifiedTokenHash = tokenHash
        if let verifyError { throw verifyError }
        if let verifiedSession { return verifiedSession }
        throw APIError.validation(message: "no session")
    }
}

private final class RecoveryVerifierNoAccess: BackendSessionVerifying {
    func fetchSessionRole(userEmail: String) async throws -> SessionRoleContext {
        SessionRoleContext(
            isSuperAdmin: false,
            isStaff: false,
            isOperator: false,
            isCustomer: false,
            persona: nil,
            staffRole: nil,
            roleLabel: nil,
            defaultPath: "/unauthorized",
            organizations: nil,
            activeOrganization: nil,
            activeSubscription: nil,
            rolePermissionOverrides: nil
        )
    }
}

private final class RecoveryVerifier: BackendSessionVerifying {
    func fetchSessionRole(userEmail: String) async throws -> SessionRoleContext {
        SessionRoleContext(
            isSuperAdmin: false,
            isStaff: false,
            isOperator: false,
            isCustomer: true,
            persona: "customer",
            staffRole: nil,
            roleLabel: "Клиент",
            defaultPath: "/client",
            organizations: nil,
            activeOrganization: nil,
            activeSubscription: nil,
            rolePermissionOverrides: nil
        )
    }
}

private final class RecoveryRegistrationService: RegistrationServicing {
    func fetchOptions() async throws -> ClientRegistrationOptionsResponse {
        ClientRegistrationOptionsResponse(companies: [], points: [])
    }
    func registerClient(body: ClientRegisterRequest) async throws {}
}

private final class RecoveryKeychain: KeychainStoring {
    func save(_ data: Data, for key: String) throws {}
    func read(for key: String) throws -> Data? { nil }
    func delete(for key: String) throws {}
}
