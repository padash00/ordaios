import Foundation
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    enum Mode: String, CaseIterable {
        case email
        case operatorLogin
    }

    @Published var mode: Mode = .email
    @Published var login: String = ""
    @Published var password: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isForgotPasswordSheetPresented = false
    @Published var isResetPasswordSheetPresented = false
    @Published var resetEmail: String = ""
    @Published var resetNewPassword: String = ""
    @Published var resetConfirmPassword: String = ""
    @Published var resetInfoMessage: String?
    @Published var isRecoveringResetLink = false
    @Published var resetResendCooldown: Int = 0

    private let sessionStore: SessionStore
    private var cancellables = Set<AnyCancellable>()
    private var resetCooldownTask: Task<Void, Never>?

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
        self.resetEmail = sessionStore.session?.userEmail ?? ""

        sessionStore.$passwordResetAccessToken
            .map { $0 != nil }
            .removeDuplicates()
            .sink { [weak self] hasToken in
                self?.isResetPasswordSheetPresented = hasToken
            }
            .store(in: &cancellables)

        sessionStore.$isRecoveringPasswordLink
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecoveringResetLink)

        sessionStore.$authMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                guard let self, let message, !message.isEmpty else { return }
                self.errorMessage = message
                self.handleAuthMessage(message)
            }
            .store(in: &cancellables)
    }

    func signIn() async {
        errorMessage = nil
        sessionStore.authMessage = nil

        guard validate() else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            try await sessionStore.login(email: normalizedAuthEmail, password: password)
        } catch {
            errorMessage = Self.mapSignInError(error)
        }
    }

    func openSignUp() {
        sessionStore.startSignUp()
    }

    func sendPasswordResetEmail() async {
        errorMessage = nil
        resetInfoMessage = nil
        guard resetResendCooldown == 0 else { return }
        let email = resetEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard email.contains("@") else {
            errorMessage = "Введите корректный email"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            try await sessionStore.requestPasswordReset(email: email)
            resetInfoMessage = "Письмо отправлено. Откройте ссылку из email на этом устройстве."
            startResetResendCooldown()
            AppHaptics.success()
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
            AppHaptics.error()
        }
    }

    func applyRecoveredPassword() async {
        errorMessage = nil
        resetInfoMessage = nil
        guard resetNewPassword.count >= 6 else {
            errorMessage = "Пароль должен содержать минимум 6 символов"
            return
        }
        guard resetNewPassword == resetConfirmPassword else {
            errorMessage = "Пароли не совпадают"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            try await sessionStore.updatePasswordViaRecovery(newPassword: resetNewPassword)
            resetNewPassword = ""
            resetConfirmPassword = ""
            isResetPasswordSheetPresented = false
            AppHaptics.success()
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
            AppHaptics.error()
        }
    }

    func closeResetFlow() {
        resetNewPassword = ""
        resetConfirmPassword = ""
        sessionStore.closePasswordRecoveryFlow()
    }

    func resendResetFromCurrentContext() async {
        let source = resetEmail.isEmpty ? login : resetEmail
        resetEmail = source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        await sendPasswordResetEmail()
    }

    var canQuickResendReset: Bool {
        guard let error = errorMessage?.lowercased() else { return false }
        let hasEmail = (resetEmail.contains("@") || login.contains("@"))
        return hasEmail
            && resetResendCooldown == 0
            && (error.contains("истекла") || error.contains("недейств") || error.contains("восстанов"))
    }

    private static func mapSignInError(_ error: Error) -> String {
        let text = APIErrorMapper().map(error: error).errorDescription ?? ""
        let lower = text.lowercased()
        if lower.contains("email_not_confirmed") || lower.contains("email not confirmed") {
            return "Сначала подтвердите email по ссылке из письма, затем войдите снова."
        }
        return text.isEmpty ? "Ошибка входа. Повторите попытку." : text
    }

    private func validate() -> Bool {
        if login.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = mode == .email ? "Введите email" : "Введите логин оператора"
            return false
        }

        if mode == .email, !login.contains("@") {
            errorMessage = "Некорректный email"
            return false
        }

        if password.count < 6 {
            errorMessage = "Пароль должен содержать минимум 6 символов"
            return false
        }

        return true
    }

    private var normalizedAuthEmail: String {
        switch mode {
        case .email:
            return login.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        case .operatorLogin:
            return AuthLoginMapper.toOperatorAuthEmail(login)
        }
    }

    private func handleAuthMessage(_ message: String) {
        let lower = message.lowercased()
        guard lower.contains("истекла") || lower.contains("недейств") || lower.contains("восстанов") else { return }
        let candidate = login.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if candidate.contains("@") {
            resetEmail = candidate
        }
        isForgotPasswordSheetPresented = true
        resetInfoMessage = "Ссылка недействительна. Запросите новое письмо."
        isResetPasswordSheetPresented = false
    }

    private func startResetResendCooldown(seconds: Int = 30) {
        resetCooldownTask?.cancel()
        resetResendCooldown = seconds
        resetCooldownTask = Task { @MainActor [weak self] in
            while let self, self.resetResendCooldown > 0, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self.resetResendCooldown -= 1
            }
        }
    }
}
