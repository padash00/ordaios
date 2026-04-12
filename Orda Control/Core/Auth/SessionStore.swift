import Foundation
import Combine

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var session: Session?
    @Published private(set) var roleContext: SessionRoleContext?
    @Published private(set) var isRestoringSession: Bool = true
    @Published private(set) var isBootstrappingRole: Bool = false
    @Published var authMessage: String?
    @Published var onboardingState: OnboardingState = .signIn
    @Published var resendCooldown: Int = 0
    @Published var passwordResetAccessToken: String?
    @Published var isRecoveringPasswordLink: Bool = false
    /// Увеличивается после регистрации/входа клиента — `MainTabView` перезагружает `GET /api/client/me`.
    @Published private(set) var clientProfileRefreshNonce: UInt = 0

    let apiClient: APIClient
    private let authService: AuthServicing
    private let backendSessionVerifier: BackendSessionVerifying
    private let registrationService: RegistrationServicing
    private let keychainStorage: KeychainStoring
    private let keychainKey = "client.session"
    /// Survives app restart after sign-up so «Проверить подтверждение» works without re-entering password.
    private let pendingSignUpKeychainKey = "client.pending-signup"
    private let roleStorageKey = "client.role.context"
    private var pendingEmail: String?
    private var pendingPassword: String?

    var isAuthenticated: Bool {
        session != nil
    }

    var shellType: AppShellType {
        AppShellResolver.resolve(from: roleContext)
    }

    init(
        apiClient: APIClient,
        authService: AuthServicing,
        backendSessionVerifier: BackendSessionVerifying,
        registrationService: RegistrationServicing,
        keychainStorage: KeychainStoring
    ) {
        self.apiClient = apiClient
        self.authService = authService
        self.backendSessionVerifier = backendSessionVerifier
        self.registrationService = registrationService
        self.keychainStorage = keychainStorage

        apiClient.setTokenProvider { [weak self] in
            self?.session?.accessToken
        }
        apiClient.setTokenRefresher { [weak self] in
            guard let self else { return false }
            return await self.refreshSessionIfNeeded()
        }
        apiClient.setUnauthorizedHandler { [weak self] in
            Task { @MainActor in
                await self?.handleUnauthorized()
            }
        }

        Task {
            await restoreSession()
        }

        NotificationCenter.default.addObserver(
            forName: .ordaDidRecordAPNsDeviceToken,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isAuthenticated else { return }
                await PushDeviceRegistrar.shared.uploadPendingTokenIfNeeded(apiClient: self.apiClient)
            }
        }
    }

    private func scheduleRemotePushPipeline() {
        Task {
            await PushDeviceRegistrar.shared.registerForRemoteNotificationsAndUpload(
                apiClient: apiClient,
                isAuthenticated: isAuthenticated
            )
        }
    }

    static func makeDefault() -> SessionStore {
        let config = AppConfig.current
        let apiClient = APIClient(config: config)
        let authService = SupabaseAuthService(config: config)
        let verifier = BackendSessionVerifier(apiClient: apiClient)
        let registrationService = RegistrationService(apiClient: apiClient)
        let keychain = KeychainStorage(service: "com.orda.client")

        return SessionStore(
            apiClient: apiClient,
            authService: authService,
            backendSessionVerifier: verifier,
            registrationService: registrationService,
            keychainStorage: keychain
        )
    }

    func login(email: String, password: String) async throws {
        authMessage = nil
        let createdSession = try await authService.signIn(email: email, password: password)
        session = createdSession

        #if DEBUG
        print("=== SIGN IN DEBUG ===")
        print("user:", createdSession.userEmail)
        print("token:", maskToken(createdSession.accessToken))
        #endif

        try await bootstrapRoleContext()
        try persist(session: createdSession)
        applyPostLoginOnboardingState()
        bumpClientProfileRefreshIfCustomer()
        scheduleRemotePushPipeline()
    }

    func startSignUp() {
        onboardingState = .signUp
    }

    func backToSignIn() {
        pendingEmail = nil
        pendingPassword = nil
        clearPendingSignUpKeychainOnly()
        onboardingState = .signIn
    }

    func signUp(email: String, password: String, confirmPassword: String) async throws {
        guard password == confirmPassword else {
            throw APIError.validation(message: "Пароли не совпадают.")
        }
        guard password.count >= 6 else {
            throw APIError.validation(message: "Пароль должен содержать минимум 6 символов")
        }
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let sessionFromSignUp = try await authService.signUp(email: normalized, password: password)
        // Сохраняем только после успешного ответа Supabase, чтобы при сбое декодирования можно было войти с экрана «Вход» после подтверждения письма.
        pendingEmail = normalized
        pendingPassword = password
        if let sessionFromSignUp {
            session = sessionFromSignUp
        }
        onboardingState = .emailConfirmationPending(email: normalized)
        persistPendingSignUpCredentials()
    }

    func checkEmailConfirmation() async throws {
        guard let email = pendingEmail, let password = pendingPassword else {
            throw APIError.validation(message: "Повторите вход после подтверждения email.")
        }
        let signedIn = try await authService.signIn(email: email, password: password)
        session = signedIn
        try persist(session: signedIn)
        clearPendingSignUpKeychainOnly()
        pendingEmail = nil
        pendingPassword = nil
        try await bootstrapRoleContext()
        applyPostLoginOnboardingState()
        bumpClientProfileRefreshIfCustomer()
    }

    func resendConfirmationEmail() async throws {
        guard resendCooldown == 0 else { return }
        guard let email = pendingEmail else {
            throw APIError.validation(message: "Email не указан.")
        }
        try await authService.resendConfirmation(email: email)
        resendCooldown = 30
        Task { @MainActor [weak self] in
            while let self, self.resendCooldown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self.resendCooldown -= 1
            }
        }
    }

    func loadRegistrationOptions() async throws -> ClientRegistrationOptionsResponse {
        try await registrationService.fetchOptions()
    }

    func completeCustomerRegistration(
        companyCode: String? = nil,
        pointProjectId: String? = nil,
        phone: String,
        name: String?
    ) async throws {
        guard session != nil else {
            throw APIError.unauthorized
        }
        let trimmedCompany = companyCode?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPoint = pointProjectId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = ClientRegisterRequest(
            phone: phone,
            name: name?.isEmpty == true ? nil : name,
            companyCode: (trimmedCompany?.isEmpty == false) ? trimmedCompany : nil,
            pointProjectId: (trimmedPoint?.isEmpty == false) ? trimmedPoint : nil
        )
        do {
            try await registrationService.registerClient(body: body)
            try await bootstrapRoleContext()
            pendingEmail = nil
            pendingPassword = nil
            clearPendingSignUpKeychainOnly()
            applyPostLoginOnboardingState()
            AppHaptics.success()
            bumpClientProfileRefreshIfCustomer()
            scheduleRemotePushPipeline()
        } catch {
            AppHaptics.error()
            throw APIError.validation(message: OnboardingErrorMapper.message(from: error))
        }
    }

    private func bumpClientProfileRefreshIfCustomer() {
        guard roleContext?.isCustomer == true else { return }
        clientProfileRefreshNonce &+= 1
    }

    func logout(clearMessage: Bool = true) async {
        session = nil
        roleContext = nil
        pendingEmail = nil
        pendingPassword = nil
        passwordResetAccessToken = nil
        onboardingState = .signIn
        if clearMessage {
            authMessage = nil
        }
        try? keychainStorage.delete(for: keychainKey)
        clearPendingSignUpKeychainOnly()
        UserDefaults.standard.removeObject(forKey: roleStorageKey)
    }

    private func restoreSession() async {
        defer { isRestoringSession = false }

        do {
            guard let data = try keychainStorage.read(for: keychainKey) else {
                restorePendingSignUpCredentialsIfStored()
                return
            }
            let restored = try JSONDecoder().decode(Session.self, from: data)
            session = restored
            clearPendingSignUpKeychainOnly()
            if let roleData = UserDefaults.standard.data(forKey: roleStorageKey),
               let cachedRole = try? JSONDecoder().decode(SessionRoleContext.self, from: roleData) {
                roleContext = cachedRole
            }
            do {
                try await bootstrapRoleContext()
                applyPostLoginOnboardingState()
                scheduleRemotePushPipeline()
            } catch {
                // Keep restored session and cached role for temporary network errors.
                if roleContext == nil {
                    authMessage = APIErrorMapper().map(error: error).errorDescription
                }
            }
        } catch {
            session = nil
            roleContext = nil
            restorePendingSignUpCredentialsIfStored()
        }
    }

    /// Если сессия есть, а роль в бэкенде не даёт ни одного shell — приводим onboarding к шагу регистрации (на случай рассинхрона с `onboardingState == .app`).
    func reconcileNoAccessClientRouteIfNeeded() {
        guard isAuthenticated else { return }
        guard AppShellResolver.resolve(from: roleContext) == .noAccess else { return }
        switch onboardingState {
        case .app, .signIn:
            onboardingState = .registrationDetails
            if authMessage == nil || (authMessage?.isEmpty ?? true) {
                authMessage = "Завершите регистрацию: укажите телефон."
            }
        default:
            break
        }
    }

    /// После входа или восстановления сессии: нет роли в бэкенде → шаг «завершение регистрации клиента», иначе основное приложение.
    private func applyPostLoginOnboardingState() {
        let shell = AppShellResolver.resolve(from: roleContext)
        if shell == .noAccess {
            onboardingState = .registrationDetails
            if authMessage == nil || (authMessage?.isEmpty ?? true) {
                authMessage = "Завершите регистрацию: укажите телефон."
            }
        } else {
            pendingEmail = nil
            pendingPassword = nil
            clearPendingSignUpKeychainOnly()
            onboardingState = .app
        }
    }

    private func persist(session: Session) throws {
        let data = try JSONEncoder().encode(session)
        try keychainStorage.save(data, for: keychainKey)
    }

    private func persist(roleContext: SessionRoleContext) {
        if let data = try? JSONEncoder().encode(roleContext) {
            UserDefaults.standard.set(data, forKey: roleStorageKey)
        }
    }

    private func refreshSessionIfNeeded() async -> Bool {
        guard let current = session, let refreshToken = current.refreshToken, !refreshToken.isEmpty else {
            return false
        }

        do {
            var refreshed = try await authService.refreshSession(refreshToken: refreshToken)
            if refreshed.userEmail.isEmpty {
                refreshed = Session(
                    accessToken: refreshed.accessToken,
                    refreshToken: refreshed.refreshToken ?? refreshToken,
                    expiresIn: refreshed.expiresIn,
                    userEmail: current.userEmail
                )
            }
            try persist(session: refreshed)
            session = refreshed
            return true
        } catch {
            return false
        }
    }

    private func bootstrapRoleContext() async throws {
        guard let currentSession = session else { return }
        isBootstrappingRole = true
        defer { isBootstrappingRole = false }

        do {
            let context = try await backendSessionVerifier.fetchSessionRole(userEmail: currentSession.userEmail)
            roleContext = context
            persist(roleContext: context)
            let resolvedShell = AppShellResolver.resolve(from: context)
            #if DEBUG
            print("[Routing] selected shell:", resolvedShell.rawValue)
            #endif
        } catch let error as APIError {
            switch error {
            case .unauthorized:
                await handleUnauthorized()
                throw APIError.unauthorized
            case .validation(let message):
                authMessage = message
                let fallback = SessionRoleContext(
                    isSuperAdmin: false,
                    isStaff: false,
                    isOperator: false,
                    isCustomer: false,
                    persona: nil,
                    staffRole: nil,
                    roleLabel: nil,
                    defaultPath: nil,
                    organizations: nil,
                    activeOrganization: nil,
                    activeSubscription: nil,
                    rolePermissionOverrides: nil
                )
                roleContext = fallback
                scheduleRemotePushPipeline()
            case .networkUnavailable, .timeout:
                authMessage = "Ошибка сети. Повторите попытку."
                throw error
            default:
                throw error
            }
        }
    }

    private func handleUnauthorized() async {
        authMessage = "Сессия истекла. Войдите снова."
        await logout(clearMessage: false)
    }

    func requestPasswordReset(email: String) async throws {
        try await authService.requestPasswordReset(
            email: email,
            redirectTo: AppConfig.current.passwordResetRedirectURL
        )
    }

    func updatePasswordViaRecovery(newPassword: String) async throws {
        guard let accessToken = passwordResetAccessToken, !accessToken.isEmpty else {
            throw APIError.validation(message: "Ссылка восстановления недействительна. Запросите письмо повторно.")
        }
        try await authService.updatePassword(accessToken: accessToken, newPassword: newPassword)
        passwordResetAccessToken = nil
        authMessage = "Пароль обновлён. Выполните вход с новым паролем."
    }

    func consumeIncomingURL(_ url: URL) {
        let full = url.absoluteString.lowercased()
        guard full.contains("reset")
            || full.contains("recovery")
            || full.contains("access_token")
            || full.contains("token_hash")
            || full.contains("type=signup")
            else { return }
        let payload = parseURLPayload(url)

        if let token = payload["access_token"], !token.isEmpty {
            if Self.isSupabasePasswordRecoveryContext(url: url, payload: payload) {
                isRecoveringPasswordLink = false
                passwordResetAccessToken = token
                onboardingState = .signIn
                authMessage = "Введите новый пароль."
                return
            }

            let refresh: String? = {
                guard let r = payload["refresh_token"], !r.isEmpty else { return nil }
                return r
            }()
            let expiresIn: Int? = {
                guard let raw = payload["expires_in"], let v = Int(raw) else { return nil }
                return v
            }()
            let emailFromJWT = Self.decodeEmailFromSupabaseJWT(token)
            let resolvedEmail = (emailFromJWT ?? pendingEmail ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let newSession = Session(
                accessToken: token,
                refreshToken: refresh,
                expiresIn: expiresIn,
                userEmail: resolvedEmail.isEmpty ? (pendingEmail ?? "") : resolvedEmail
            )
            session = newSession
            do {
                try persist(session: newSession)
            } catch {
                session = nil
                authMessage = "Не удалось сохранить сессию."
                return
            }
            clearPendingSignUpKeychainOnly()
            pendingEmail = nil
            pendingPassword = nil
            Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    try await self.bootstrapRoleContext()
                    self.applyPostLoginOnboardingState()
                    self.scheduleRemotePushPipeline()
                } catch {
                    self.authMessage = APIErrorMapper().map(error: error).errorDescription
                }
            }
            return
        }

        if let tokenHash = payload["token_hash"], !tokenHash.isEmpty,
           Self.isSupabasePasswordRecoveryContext(url: url, payload: payload) {
            Task { @MainActor in
                isRecoveringPasswordLink = true
                do {
                    let verified = try await authService.verifyRecoveryTokenHash(tokenHash)
                    passwordResetAccessToken = verified.accessToken
                    onboardingState = .signIn
                    authMessage = "Введите новый пароль."
                } catch {
                    authMessage = "Ссылка восстановления недействительна или истекла. Запросите новое письмо."
                }
                isRecoveringPasswordLink = false
            }
        }
    }

    private static func isSupabasePasswordRecoveryContext(url: URL, payload: [String: String]) -> Bool {
        if payload["type"]?.lowercased() == "recovery" { return true }
        let full = url.absoluteString.lowercased()
        if full.contains("reset-password") || full.contains("reset_password") { return true }
        if url.path.lowercased().contains("/auth/reset") { return true }
        return false
    }

    /// Reads `email` claim from a JWT payload (Supabase access tokens).
    private static func decodeEmailFromSupabaseJWT(_ accessToken: String) -> String? {
        let parts = accessToken.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let email = json["email"] as? String
        else { return nil }
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }

    private func persistPendingSignUpCredentials() {
        guard let email = pendingEmail, let password = pendingPassword else { return }
        let payload = ["email": email, "password": password]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        try? keychainStorage.save(data, for: pendingSignUpKeychainKey)
    }

    private func clearPendingSignUpKeychainOnly() {
        try? keychainStorage.delete(for: pendingSignUpKeychainKey)
    }

    private func restorePendingSignUpCredentialsIfStored() {
        guard session == nil else { return }
        guard let data = try? keychainStorage.read(for: pendingSignUpKeychainKey),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let email = obj["email"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              let password = obj["password"],
              !email.isEmpty,
              !password.isEmpty
        else { return }
        pendingEmail = email
        pendingPassword = password
        onboardingState = .emailConfirmationPending(email: email)
    }

    func closePasswordRecoveryFlow() {
        passwordResetAccessToken = nil
        isRecoveringPasswordLink = false
    }

    private func parseURLPayload(_ url: URL) -> [String: String] {
        var result: [String: String] = [:]
        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = comps.queryItems {
            for item in queryItems where item.value != nil {
                result[item.name.lowercased()] = item.value
            }
            if let fragment = comps.fragment {
                for pair in fragment.split(separator: "&") {
                    let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
                    guard parts.count == 2 else { continue }
                    result[parts[0].lowercased()] = parts[1].removingPercentEncoding ?? parts[1]
                }
            }
        }
        return result
    }

    private func maskToken(_ token: String) -> String {
        let prefix = token.prefix(10)
        let suffix = token.suffix(6)
        return "\(prefix)...\(suffix)"
    }
}
