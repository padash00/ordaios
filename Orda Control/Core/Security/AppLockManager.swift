import LocalAuthentication
import SwiftUI
import Combine

@MainActor
final class AppLockManager: ObservableObject {
    @Published var isLocked: Bool = false
    @Published var biometricType: BiometricType = .none
    /// Time in background after which app requires re-authentication.
    @Published var backgroundLockTimeout: TimeInterval

    enum BiometricType {
        case faceID, touchID, none
    }

    private let context = LAContext()
    private var enteredBackgroundAt: Date?
    private let defaults: UserDefaults
    private let lockTimeoutKey = "app.lock.timeout.seconds"
    private let defaultTimeoutSeconds: TimeInterval

    static let supportedTimeoutMinutes: [Int] = [1, 2, 5, 10, 15]

    init(backgroundLockTimeout: TimeInterval = 120, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let fallback = max(0, backgroundLockTimeout)
        self.defaultTimeoutSeconds = fallback
        let stored = defaults.double(forKey: lockTimeoutKey)
        if stored > 0 {
            self.backgroundLockTimeout = stored
        } else {
            self.backgroundLockTimeout = fallback
        }
        detectBiometricType()
    }

    private func detectBiometricType() {
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometricType = .none
            return
        }
        switch context.biometryType {
        case .faceID: biometricType = .faceID
        case .touchID: biometricType = .touchID
        default: biometricType = .none
        }
    }

    func lockApp() {
        guard canUseDeviceAuthentication() else { return }
        isLocked = true
    }

    func authenticate() async {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            isLocked = false
            return
        }
        do {
            let success = try await ctx.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Войдите в Orda Control"
            )
            if success { isLocked = false }
        } catch {
            // пользователь может повторить
        }
    }

    func handleDidEnterBackground() {
        enteredBackgroundAt = Date()
    }

    func handleDidBecomeActive() async {
        defer { enteredBackgroundAt = nil }

        if isLocked {
            await authenticate()
            return
        }

        guard let enteredBackgroundAt else { return }
        let elapsed = Date().timeIntervalSince(enteredBackgroundAt)
        guard elapsed >= backgroundLockTimeout else { return }

        lockApp()
        if isLocked {
            await authenticate()
        }
    }

    var timeoutMinutesLabel: String {
        let mins = Int(backgroundLockTimeout / 60)
        return "\(mins) мин"
    }

    var defaultTimeoutMinutesLabel: String {
        let mins = Int(defaultTimeoutSeconds / 60)
        return "\(mins) мин"
    }

    var usesCustomTimeout: Bool {
        defaults.object(forKey: lockTimeoutKey) != nil
    }

    func setTimeoutMinutes(_ minutes: Int) {
        let normalized = max(1, minutes)
        let seconds = TimeInterval(normalized * 60)
        backgroundLockTimeout = seconds
        defaults.set(seconds, forKey: lockTimeoutKey)
    }

    func resetTimeoutToDefault() {
        defaults.removeObject(forKey: lockTimeoutKey)
        backgroundLockTimeout = defaultTimeoutSeconds
    }

    private func canUseDeviceAuthentication() -> Bool {
        let ctx = LAContext()
        var error: NSError?
        return ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }
}
