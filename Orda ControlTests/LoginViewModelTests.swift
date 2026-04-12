import XCTest
@testable import Orda_Control

@MainActor
final class LoginViewModelTests: XCTestCase {
    func testSignInShowsEmailConfirmationMessage() async {
        let apiClient = APIClient(config: .testLoginVM)
        let auth = LoginVMAuthService()
        auth.signInError = APIError.validation(message: "email_not_confirmed")
        let store = SessionStore(
            apiClient: apiClient,
            authService: auth,
            backendSessionVerifier: LoginVMVerifier(),
            registrationService: LoginVMRegistrationService(),
            keychainStorage: LoginVMKeychain()
        )
        let vm = LoginViewModel(sessionStore: store)
        vm.login = "new@user.com"
        vm.password = "123456"

        await vm.signIn()

        XCTAssertEqual(vm.errorMessage, "Сначала подтвердите email по ссылке из письма, затем войдите снова.")
    }

    func testSignInValidationForShortPassword() async {
        let apiClient = APIClient(config: .testLoginVM)
        let store = SessionStore(
            apiClient: apiClient,
            authService: LoginVMAuthService(),
            backendSessionVerifier: LoginVMVerifier(),
            registrationService: LoginVMRegistrationService(),
            keychainStorage: LoginVMKeychain()
        )
        let vm = LoginViewModel(sessionStore: store)
        vm.login = "user@test.com"
        vm.password = "123"

        await vm.signIn()

        XCTAssertEqual(vm.errorMessage, "Пароль должен содержать минимум 6 символов")
    }

    func testSignInValidationForOperatorLoginMode() async {
        let apiClient = APIClient(config: .testLoginVM)
        let auth = LoginVMAuthService()
        auth.signInSession = Session(accessToken: "token", refreshToken: "refresh", expiresIn: 3600, userEmail: "operator_1@operator.local")
        let store = SessionStore(
            apiClient: apiClient,
            authService: auth,
            backendSessionVerifier: LoginVMVerifier(),
            registrationService: LoginVMRegistrationService(),
            keychainStorage: LoginVMKeychain()
        )
        let vm = LoginViewModel(sessionStore: store)
        vm.mode = .operatorLogin
        vm.login = "operator_1"
        vm.password = "123456"

        await vm.signIn()

        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(auth.lastSignInEmail, AuthLoginMapper.toOperatorAuthEmail("operator_1"))
    }

    func testAuthMessageAboutExpiredLinkOpensForgotPasswordSheet() async {
        let apiClient = APIClient(config: .testLoginVM)
        let store = SessionStore(
            apiClient: apiClient,
            authService: LoginVMAuthService(),
            backendSessionVerifier: LoginVMVerifier(),
            registrationService: LoginVMRegistrationService(),
            keychainStorage: LoginVMKeychain()
        )
        let vm = LoginViewModel(sessionStore: store)
        vm.login = "recover@test.com"

        store.authMessage = "Ссылка восстановления недействительна или истекла."
        await waitUntil { vm.isForgotPasswordSheetPresented }

        XCTAssertEqual(vm.resetEmail, "recover@test.com")
        XCTAssertEqual(vm.resetInfoMessage, "Ссылка недействительна. Запросите новое письмо.")
        XCTAssertFalse(vm.isResetPasswordSheetPresented)
    }

    func testRecoveryDeepLinkWithAccessTokenOpensResetSheet() async {
        let apiClient = APIClient(config: .testLoginVM)
        let store = SessionStore(
            apiClient: apiClient,
            authService: LoginVMAuthService(),
            backendSessionVerifier: LoginVMVerifier(),
            registrationService: LoginVMRegistrationService(),
            keychainStorage: LoginVMKeychain()
        )
        let vm = LoginViewModel(sessionStore: store)

        store.consumeIncomingURL(URL(string: "orda-control://auth/reset-password#access_token=abc123&type=recovery")!)
        await waitUntil { vm.isResetPasswordSheetPresented }

        XCTAssertTrue(vm.isResetPasswordSheetPresented)
        XCTAssertFalse(vm.isRecoveringResetLink)
    }

    private func waitUntil(timeout: TimeInterval = 1.0, condition: @escaping () -> Bool) async {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Timeout waiting for condition")
    }
}

private extension AppConfig {
    static var testLoginVM: AppConfig {
        AppConfig(
            environment: .development,
            apiBaseURL: URL(string: "https://www.ordaops.kz")!,
            supabaseURL: URL(string: "https://example.supabase.co")!,
            supabaseAnonKey: "test-key",
            passwordResetRedirectURL: "orda-control://auth/reset-password"
        )
    }
}

private final class LoginVMAuthService: AuthServicing {
    var signInSession: Session?
    var signInError: Error?
    var lastSignInEmail: String?

    func signIn(email: String, password: String) async throws -> Session {
        lastSignInEmail = email
        if let signInError { throw signInError }
        if let signInSession { return signInSession }
        throw APIError.validation(message: "sign-in-missing")
    }

    func refreshSession(refreshToken: String) async throws -> Session {
        Session(accessToken: "token2", refreshToken: refreshToken, expiresIn: 3600, userEmail: "user@test.com")
    }

    func signUp(email: String, password: String) async throws -> Session? { nil }
    func resendConfirmation(email: String) async throws {}
    func requestPasswordReset(email: String, redirectTo: String) async throws {}
    func updatePassword(accessToken: String, newPassword: String) async throws {}
    func verifyRecoveryTokenHash(_ tokenHash: String) async throws -> Session {
        Session(accessToken: "recovery", refreshToken: nil, expiresIn: 300, userEmail: "user@test.com")
    }
}

private final class LoginVMVerifier: BackendSessionVerifying {
    func fetchSessionRole(userEmail: String) async throws -> SessionRoleContext {
        SessionRoleContext(
            isSuperAdmin: false,
            isStaff: false,
            isOperator: true,
            isCustomer: false,
            persona: "operator",
            staffRole: nil,
            roleLabel: "Оператор",
            defaultPath: "/operator",
            organizations: nil,
            activeOrganization: nil,
            activeSubscription: nil,
            rolePermissionOverrides: nil
        )
    }
}

private final class LoginVMRegistrationService: RegistrationServicing {
    func fetchOptions() async throws -> ClientRegistrationOptionsResponse {
        ClientRegistrationOptionsResponse(companies: [], points: [])
    }
    func registerClient(body: ClientRegisterRequest) async throws {}
}

private final class LoginVMKeychain: KeychainStoring {
    func save(_ data: Data, for key: String) throws {}
    func read(for key: String) throws -> Data? { nil }
    func delete(for key: String) throws {}
}
