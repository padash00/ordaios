import Foundation

@MainActor
final class AuthManager {
    private let sessionStore: SessionStore

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }

    func signIn(email: String, password: String) async throws {
        try await sessionStore.login(email: email, password: password)
    }

    func signUp(email: String, password: String, confirmPassword: String) async throws {
        try await sessionStore.signUp(email: email, password: password, confirmPassword: confirmPassword)
    }

    func checkEmailConfirmation() async throws {
        try await sessionStore.checkEmailConfirmation()
    }

    func resendConfirmationEmail() async throws {
        try await sessionStore.resendConfirmationEmail()
    }
}
