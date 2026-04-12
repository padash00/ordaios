import SwiftUI
import UIKit

@main
struct Orda_ControlApp: App {
    @UIApplicationDelegateAdaptor(OrdaControlAppDelegate.self) private var appDelegate
    @StateObject private var sessionStore: SessionStore
    @StateObject private var lockManager: AppLockManager
    @StateObject private var quickHub: AppQuickHubCoordinator
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let config = AppConfig.current
        _sessionStore = StateObject(wrappedValue: SessionStore.makeDefault())
        _lockManager = StateObject(wrappedValue: AppLockManager(backgroundLockTimeout: config.appLockTimeoutSeconds))
        _quickHub = StateObject(wrappedValue: AppQuickHubCoordinator())
        setupQuickActions()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                AppRootView()
                    .environmentObject(sessionStore)
                    .environmentObject(lockManager)
                    .environmentObject(quickHub)
                    .preferredColorScheme(.dark)

                // Blur overlay when app is in switcher
                if scenePhase != .active {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }

                // Lock screen
                if lockManager.isLocked {
                    AppLockView(lockManager: lockManager)
                        .transition(.opacity)
                        .zIndex(999)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: scenePhase == .active)
            .animation(.easeInOut(duration: 0.25), value: lockManager.isLocked)
            .onOpenURL { url in
                sessionStore.consumeIncomingURL(url)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhase(newPhase)
        }
    }

    // MARK: - Scene phase handling

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            // Store timestamp; lock is applied only after configured timeout.
            lockManager.handleDidEnterBackground()
        case .active:
            Task { await lockManager.handleDidBecomeActive() }
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    // MARK: - Home Screen Quick Actions

    private func setupQuickActions() {
        UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(
                type: "com.orda.control.income",
                localizedTitle: "Новый доход",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "arrow.up.circle.fill"),
                userInfo: nil
            ),
            UIApplicationShortcutItem(
                type: "com.orda.control.expense",
                localizedTitle: "Новый расход",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "arrow.down.circle.fill"),
                userInfo: nil
            ),
            UIApplicationShortcutItem(
                type: "com.orda.control.tasks",
                localizedTitle: "Задачи",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "checklist"),
                userInfo: nil
            ),
        ]
    }
}
