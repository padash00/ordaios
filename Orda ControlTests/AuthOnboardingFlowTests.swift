import XCTest
@testable import Orda_Control

@MainActor
final class AuthOnboardingFlowTests: XCTestCase {
    func testLoginWithNoAccessRoutesToRegistrationDetails() async throws {
        let auth = FlowAuthService()
        auth.signInSession = Session(
            accessToken: "token",
            refreshToken: "refresh",
            expiresIn: 3600,
            userEmail: "new-client@test.com"
        )
        let verifier = FlowVerifier()
        verifier.context = SessionRoleContext(
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

        let store = makeStore(auth: auth, verifier: verifier)
        try await store.login(email: "new-client@test.com", password: "123456")

        XCTAssertEqual(store.onboardingState, .registrationDetails)
        XCTAssertEqual(store.shellType, .noAccess)
        XCTAssertEqual(store.authMessage, "Завершите регистрацию: укажите телефон.")
    }

    func testLoginWithCustomerRoleRoutesToApp() async throws {
        let auth = FlowAuthService()
        auth.signInSession = Session(
            accessToken: "token",
            refreshToken: "refresh",
            expiresIn: 3600,
            userEmail: "client@test.com"
        )
        let verifier = FlowVerifier()
        verifier.context = SessionRoleContext(
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

        let store = makeStore(auth: auth, verifier: verifier)
        try await store.login(email: "client@test.com", password: "123456")

        XCTAssertEqual(store.onboardingState, .app)
        XCTAssertEqual(store.shellType, .client)
        XCTAssertNil(store.authMessage)
    }

    func testSignUpMovesToEmailConfirmationPending() async throws {
        let auth = FlowAuthService()
        auth.signUpSession = nil
        let verifier = FlowVerifier()
        let registration = FlowRegistrationService()
        let store = makeStore(auth: auth, verifier: verifier, registration: registration)

        try await store.signUp(email: "  NewUser@Test.com ", password: "123456", confirmPassword: "123456")

        XCTAssertEqual(auth.lastSignUpEmail, "newuser@test.com")
        XCTAssertEqual(auth.lastSignUpPassword, "123456")
        XCTAssertEqual(store.onboardingState, .emailConfirmationPending(email: "newuser@test.com"))
    }

    func testCheckEmailConfirmationSignsInAndOpensRegistrationDetailsWhenNoAccess() async throws {
        let auth = FlowAuthService()
        auth.signUpSession = nil
        auth.signInSession = Session(
            accessToken: "confirmed-token",
            refreshToken: "refresh",
            expiresIn: 3600,
            userEmail: "newuser@test.com"
        )
        let verifier = FlowVerifier()
        verifier.context = SessionRoleContext(
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
        let registration = FlowRegistrationService()
        let store = makeStore(auth: auth, verifier: verifier, registration: registration)

        try await store.signUp(email: "newuser@test.com", password: "123456", confirmPassword: "123456")
        try await store.checkEmailConfirmation()

        XCTAssertEqual(auth.lastSignInEmail, "newuser@test.com")
        XCTAssertEqual(store.onboardingState, .registrationDetails)
        XCTAssertEqual(store.shellType, .noAccess)
    }

    func testCompleteCustomerRegistrationRoutesToClientApp() async throws {
        let auth = FlowAuthService()
        auth.signInSession = Session(
            accessToken: "token",
            refreshToken: "refresh",
            expiresIn: 3600,
            userEmail: "client@test.com"
        )
        let verifier = FlowVerifier()
        verifier.context = SessionRoleContext(
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
        let registration = FlowRegistrationService()
        let store = makeStore(auth: auth, verifier: verifier, registration: registration)
        try await store.login(email: "client@test.com", password: "123456")

        try await store.completeCustomerRegistration(
            companyCode: "f16",
            pointProjectId: "123e4567-e89b-12d3-a456-426614174000",
            phone: "+77001234567",
            name: "Test User"
        )

        XCTAssertEqual(registration.lastBody?.companyCode, "f16")
        XCTAssertEqual(registration.lastBody?.pointProjectId, "123e4567-e89b-12d3-a456-426614174000")
        XCTAssertEqual(registration.lastBody?.phone, "+77001234567")
        XCTAssertEqual(registration.lastBody?.name, "Test User")
        XCTAssertEqual(store.onboardingState, .app)
        XCTAssertEqual(store.shellType, .client)
    }

    func testCheckEmailConfirmationWithoutPendingCredentialsThrowsValidation() async {
        let auth = FlowAuthService()
        let verifier = FlowVerifier()
        let store = makeStore(auth: auth, verifier: verifier)

        do {
            try await store.checkEmailConfirmation()
            XCTFail("Expected validation error")
        } catch {
            let mapped = APIErrorMapper().map(error: error)
            guard case .validation(let message) = mapped else {
                XCTFail("Expected validation error, got \(mapped)")
                return
            }
            XCTAssertTrue(message.contains("Повторите вход"))
        }
    }

    func testFailedSignUpDoesNotAllowCheckEmailConfirmation() async {
        let auth = FlowAuthService()
        auth.signUpError = APIError.validation(message: "signup-failed")
        let verifier = FlowVerifier()
        let store = makeStore(auth: auth, verifier: verifier)

        do {
            try await store.signUp(email: "x@test.com", password: "123456", confirmPassword: "123456")
            XCTFail("Expected signUp to fail")
        } catch {
            // expected
        }

        do {
            try await store.checkEmailConfirmation()
            XCTFail("Expected validation because pending credentials should be absent")
        } catch {
            let mapped = APIErrorMapper().map(error: error)
            guard case .validation(let message) = mapped else {
                XCTFail("Expected validation error, got \(mapped)")
                return
            }
            XCTAssertTrue(message.contains("Повторите вход"))
        }
    }

    func testCompleteCustomerRegistrationWithoutSessionThrowsUnauthorized() async {
        let auth = FlowAuthService()
        let verifier = FlowVerifier()
        let store = makeStore(auth: auth, verifier: verifier)

        do {
            try await store.completeCustomerRegistration(
                companyCode: nil,
                pointProjectId: nil,
                phone: "+77001234567",
                name: "No Session"
            )
            XCTFail("Expected unauthorized error")
        } catch {
            let mapped = APIErrorMapper().map(error: error)
            XCTAssertEqual(mapped, .unauthorized)
        }
    }

    private func makeStore(
        auth: FlowAuthService,
        verifier: FlowVerifier,
        registration: FlowRegistrationService = FlowRegistrationService()
    ) -> SessionStore {
        SessionStore(
            apiClient: APIClient(config: .testFlow),
            authService: auth,
            backendSessionVerifier: verifier,
            registrationService: registration,
            keychainStorage: FlowKeychain()
        )
    }
}

private extension AppConfig {
    static var testFlow: AppConfig {
        AppConfig(
            environment: .development,
            apiBaseURL: URL(string: "https://www.ordaops.kz")!,
            supabaseURL: URL(string: "https://example.supabase.co")!,
            supabaseAnonKey: "test-key",
            passwordResetRedirectURL: "orda-control://auth/reset-password"
        )
    }
}

private final class FlowAuthService: AuthServicing {
    var signInSession: Session?
    var signUpSession: Session?
    var signUpError: Error?
    var lastSignUpEmail: String?
    var lastSignUpPassword: String?
    var lastSignInEmail: String?

    func signIn(email: String, password: String) async throws -> Session {
        lastSignInEmail = email
        if let signInSession { return signInSession }
        throw APIError.validation(message: "missing session")
    }

    func refreshSession(refreshToken: String) async throws -> Session {
        Session(accessToken: "token2", refreshToken: refreshToken, expiresIn: 3600, userEmail: "client@test.com")
    }

    func signUp(email: String, password: String) async throws -> Session? {
        if let signUpError { throw signUpError }
        lastSignUpEmail = email
        lastSignUpPassword = password
        return signUpSession
    }
    func resendConfirmation(email: String) async throws {}
    func requestPasswordReset(email: String, redirectTo: String) async throws {}
    func updatePassword(accessToken: String, newPassword: String) async throws {}
    func verifyRecoveryTokenHash(_ tokenHash: String) async throws -> Session {
        Session(accessToken: "recovery", refreshToken: nil, expiresIn: 300, userEmail: "client@test.com")
    }
}

private final class FlowVerifier: BackendSessionVerifying {
    var context: SessionRoleContext?

    func fetchSessionRole(userEmail: String) async throws -> SessionRoleContext {
        if let context { return context }
        throw APIError.validation(message: "missing context")
    }
}

private final class FlowRegistrationService: RegistrationServicing {
    var lastBody: ClientRegisterRequest?

    func fetchOptions() async throws -> ClientRegistrationOptionsResponse {
        ClientRegistrationOptionsResponse(companies: [], points: [])
    }
    func registerClient(body: ClientRegisterRequest) async throws {
        lastBody = body
    }
}

private final class FlowKeychain: KeychainStoring {
    private var storage: [String: Data] = [:]
    func save(_ data: Data, for key: String) throws { storage[key] = data }
    func read(for key: String) throws -> Data? { storage[key] }
    func delete(for key: String) throws { storage.removeValue(forKey: key) }
}
