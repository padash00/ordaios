import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var quickHub: AppQuickHubCoordinator
    @StateObject private var clientProfileStore = ClientProfileStore()
    @State private var selectedTab: ClientMainTab = .home

    var body: some View {
        Group {
            if sessionStore.shellType == .client {
                TabView(selection: $selectedTab) {
                    NavigationStack {
                        HomeView(viewModel: HomeViewModel(service: HomeService(apiClient: sessionStore.apiClient)))
                    }
                    .tabItem {
                        Label("Главная", systemImage: "house")
                    }
                    .tag(ClientMainTab.home)

                    NavigationStack {
                        BookingsView(
                            viewModel: BookingsViewModel(
                                service: BookingService(apiClient: sessionStore.apiClient),
                                profileStore: clientProfileStore
                            )
                        )
                    }
                    .tabItem {
                        Label("Брони", systemImage: "calendar")
                    }
                    .tag(ClientMainTab.bookings)

                    NavigationStack {
                        PointsView(viewModel: PointsViewModel(service: PointsService(apiClient: sessionStore.apiClient)))
                    }
                    .tabItem {
                        Label("Баллы", systemImage: "star.circle")
                    }
                    .tag(ClientMainTab.points)

                    NavigationStack {
                        SupportView(
                            viewModel: SupportViewModel(
                                service: SupportService(apiClient: sessionStore.apiClient),
                                profileStore: clientProfileStore
                            )
                        )
                    }
                    .tabItem {
                        Label("Поддержка", systemImage: "message")
                    }
                    .tag(ClientMainTab.support)
                }
                .environmentObject(clientProfileStore)
                .onChange(of: sessionStore.clientProfileRefreshNonce) { _, _ in
                    Task {
                        await clientProfileStore.refresh(apiClient: sessionStore.apiClient)
                    }
                }
                .onChange(of: quickHub.navigationEvent) { _, new in
                    guard let new else { return }
                    if case .client(let tab) = new {
                        selectedTab = tab
                    }
                    Task { @MainActor in quickHub.clearNavigation() }
                }
            } else {
                NoAccessView()
            }
        }
        .tint(AppTheme.Colors.accentPrimary)
    }
}
