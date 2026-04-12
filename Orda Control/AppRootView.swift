import SwiftUI
import Combine

struct AppRootView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var quickHub: AppQuickHubCoordinator
    @StateObject private var registrationViewModel = RegistrationViewModelHolder()

    var body: some View {
        Group {
            if sessionStore.isRestoringSession {
                LoadingStateView(message: "Загрузка...")
            } else if sessionStore.isAuthenticated {
                if sessionStore.onboardingState == .registrationDetails {
                    RegistrationDetailsView(viewModel: registrationViewModel.resolve(for: sessionStore))
                } else if sessionStore.isBootstrappingRole {
                    LoadingStateView(message: "Загрузка...")
                } else if sessionStore.shellType == .noAccess {
                    // Учётка Supabase есть, но в бэкенде нет роли клиента/сотрудника — не «Нет доступа», а завершение регистрации.
                    RegistrationDetailsView(viewModel: registrationViewModel.resolve(for: sessionStore))
                        .task { sessionStore.reconcileNoAccessClientRouteIfNeeded() }
                } else {
                    ZStack(alignment: .bottomTrailing) {
                        shellForCurrentRole
                        if sessionStore.shellType != .noAccess {
                            AppQuickHubFloatingButton()
                        }
                    }
                    .onChange(of: sessionStore.shellType) { _, new in
                        if new != .operatorRole {
                            quickHub.operatorLeadTabAvailable = false
                        }
                    }
                    .sheet(isPresented: $quickHub.isPresented) {
                        AppQuickHubSheet()
                            .environmentObject(sessionStore)
                            .environmentObject(quickHub)
                    }
                }
            } else if sessionStore.onboardingState == .signUp {
                RegistrationStartView(viewModel: registrationViewModel.resolve(for: sessionStore)) {
                    sessionStore.backToSignIn()
                }
            } else if case .emailConfirmationPending(let email) = sessionStore.onboardingState {
                EmailConfirmationView(viewModel: registrationViewModel.resolve(for: sessionStore), email: email)
            } else {
                LoginView(sessionStore: sessionStore)
            }
        }
        .animation(.easeInOut, value: sessionStore.isAuthenticated)
        .onChange(of: sessionStore.isAuthenticated) { _, ok in
            if !ok {
                quickHub.isPresented = false
                quickHub.navigationEvent = nil
                quickHub.operatorLeadTabAvailable = false
            }
        }
    }

    @ViewBuilder
    private var shellForCurrentRole: some View {
        switch sessionStore.shellType {
        case .admin:
            AdminRootView()
        case .staff:
            StaffRootView()
        case .operatorRole:
            OperatorRootView()
        case .client:
            ClientRootView()
        case .noAccess:
            AccessDeniedView()
        }
    }
}

@MainActor
private final class RegistrationViewModelHolder: ObservableObject {
    private var vm: RegistrationViewModel?
    private weak var store: SessionStore?

    func resolve(for store: SessionStore) -> RegistrationViewModel {
        if self.store !== store {
            self.store = store
            vm = RegistrationViewModel(sessionStore: store)
        }
        return vm!
    }
}
