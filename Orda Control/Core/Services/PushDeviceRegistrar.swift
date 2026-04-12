import Foundation
import UIKit
import UserNotifications

extension Notification.Name {
    /// Posted on main after APNs device token is received and stored locally.
    static let ordaDidRecordAPNsDeviceToken = Notification.Name("ordaDidRecordAPNsDeviceToken")
}

/// Registers for APNs and uploads the device token to `/api/me/push-token` (Phase 3).
@MainActor
final class PushDeviceRegistrar {
    static let shared = PushDeviceRegistrar()

    private let pendingKey = "orda.apns.device_token.hex.pending"
    private var pendingHexFromMemory: String?

    private init() {}

    func recordDeviceToken(_ data: Data) {
        let hex = data.map { String(format: "%02x", $0) }.joined()
        guard !hex.isEmpty else { return }
        pendingHexFromMemory = hex
        UserDefaults.standard.set(hex, forKey: pendingKey)
        NotificationCenter.default.post(name: .ordaDidRecordAPNsDeviceToken, object: nil)
    }

    private func currentPendingHex() -> String? {
        pendingHexFromMemory ?? UserDefaults.standard.string(forKey: pendingKey)
    }

    /// Requests notification permission, registers with APNs, uploads if token already known.
    func registerForRemoteNotificationsAndUpload(apiClient: APIClient, isAuthenticated: Bool) async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        UIApplication.shared.registerForRemoteNotifications()
        if isAuthenticated {
            await uploadPendingTokenIfNeeded(apiClient: apiClient)
        }
    }

    func uploadPendingTokenIfNeeded(apiClient: APIClient) async {
        guard let hex = currentPendingHex(), hex.count >= 32 else { return }

        struct Body: Encodable {
            let deviceToken: String
            let bundleId: String?
        }

        struct OK: Decodable {
            let ok: Bool?
        }

        let bundleId = Bundle.main.bundleIdentifier
        let endpoint = ContractEndpoint.api_me_push_token.post
        do {
            let _: OK = try await apiClient.request(endpoint, body: Body(deviceToken: hex, bundleId: bundleId))
        } catch {
            #if DEBUG
            print("[APNs] upload token failed:", error)
            #endif
        }
    }
}
