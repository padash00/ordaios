import XCTest
@testable import Orda_Control

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    func testSignUpSuccessSetsInfoMessage() async {
        let apiClient = APIClient(config: .test)
        let auth = MockAuthService(
            signInResult: .success(Session(accessToken: "token", refreshToken: "refresh", expiresIn: 3600, userEmail: "user@test.com")),
            signUpResult: .success(nil),
            refreshResult: .success(Session(accessToken: "token", refreshToken: "refresh", expiresIn: 3600, userEmail: "user@test.com"))
        )
        let verifier = MockSessionVerifier(
            result: .success(
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
            )
        )
        let registration = MockRegistrationService()
        let keychain = InMemoryKeychain()

        let store = SessionStore(
            apiClient: apiClient,
            authService: auth,
            backendSessionVerifier: verifier,
            registrationService: registration,
            keychainStorage: keychain
        )
        let vm = RegistrationViewModel(sessionStore: store)
        vm.signUpEmail = "new@user.com"
        vm.signUpPassword = "123456"
        vm.confirmPassword = "123456"

        await vm.signUp()

        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.infoMessage, "Проверьте email для подтверждения.")
    }
}

private extension AppConfig {
    static var test: AppConfig {
        AppConfig(
            environment: .development,
            apiBaseURL: URL(string: "https://www.ordaops.kz")!,
            supabaseURL: URL(string: "https://example.supabase.co")!,
            supabaseAnonKey: "test-key",
            passwordResetRedirectURL: "orda-control://auth/reset-password"
        )
    }
}

private final class MockAuthService: AuthServicing {
    let signInResult: Result<Session, Error>
    let signUpResult: Result<Session?, Error>
    let refreshResult: Result<Session, Error>

    init(signInResult: Result<Session, Error>, signUpResult: Result<Session?, Error>, refreshResult: Result<Session, Error>) {
        self.signInResult = signInResult
        self.signUpResult = signUpResult
        self.refreshResult = refreshResult
    }

    func signIn(email: String, password: String) async throws -> Session { try signInResult.get() }
    func refreshSession(refreshToken: String) async throws -> Session { try refreshResult.get() }
    func signUp(email: String, password: String) async throws -> Session? { try signUpResult.get() }
    func resendConfirmation(email: String) async throws {}
    func requestPasswordReset(email: String, redirectTo: String) async throws {}
    func updatePassword(accessToken: String, newPassword: String) async throws {}
    func verifyRecoveryTokenHash(_ tokenHash: String) async throws -> Session { try signInResult.get() }
}

private final class MockSessionVerifier: BackendSessionVerifying {
    let result: Result<SessionRoleContext, Error>
    init(result: Result<SessionRoleContext, Error>) { self.result = result }
    func fetchSessionRole(userEmail: String) async throws -> SessionRoleContext { try result.get() }
}

private final class MockRegistrationService: RegistrationServicing {
    func fetchOptions() async throws -> ClientRegistrationOptionsResponse {
        ClientRegistrationOptionsResponse(companies: [], points: [])
    }
    func registerClient(body: ClientRegisterRequest) async throws {}
}

private final class InMemoryKeychain: KeychainStoring {
    private var storage: [String: Data] = [:]
    func save(_ data: Data, for key: String) throws { storage[key] = data }
    func read(for key: String) throws -> Data? { storage[key] }
    func delete(for key: String) throws { storage[key] = nil }
}
