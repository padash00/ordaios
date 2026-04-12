import Foundation

protocol SessionBootstrapping {
    func bootstrapRole() async throws -> SessionRoleContext
}

final class SessionBootstrapService: SessionBootstrapping {
    private let verifier: BackendSessionVerifying
    private let userEmailProvider: () -> String

    init(verifier: BackendSessionVerifying, userEmailProvider: @escaping () -> String) {
        self.verifier = verifier
        self.userEmailProvider = userEmailProvider
    }

    func bootstrapRole() async throws -> SessionRoleContext {
        try await verifier.fetchSessionRole(userEmail: userEmailProvider())
    }
}
