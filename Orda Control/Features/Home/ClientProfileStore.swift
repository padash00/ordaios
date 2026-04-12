import Foundation
import Combine

/// Клиентский профиль из `GET /api/client/me`: все `customers`, выбор активной строки (точка/компания) для броней, поддержки и станций.
@MainActor
final class ClientProfileStore: ObservableObject {
    private static let selectionDefaultsKey = "orda.client.selectedCustomerId"

    @Published private(set) var customers: [ActiveCustomer] = []
    @Published private(set) var persona: String?
    /// Стартует в `true`, чтобы на первом кадре «Главная» не мигала пустая карточка до `GET /me`.
    @Published private(set) var isLoading = true
    @Published private(set) var loadError: String?

    @Published var selectedCustomerId: String? {
        didSet {
            if let id = selectedCustomerId, !id.isEmpty {
                UserDefaults.standard.set(id, forKey: Self.selectionDefaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.selectionDefaultsKey)
            }
        }
    }

    var selectedCustomer: ActiveCustomer? {
        guard let id = selectedCustomerId, !id.isEmpty else { return customers.first }
        return customers.first { $0.id == id } ?? customers.first
    }

    /// `companies.id` для POST с `companyId` (совпадает с `customers.company_id` на бэкенде).
    var selectedCompanyId: String? {
        let raw = selectedCustomer?.companyId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? nil : raw
    }

    init() {
        selectedCustomerId = UserDefaults.standard.string(forKey: Self.selectionDefaultsKey)
    }

    func refresh(apiClient: APIClient) async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let endpoint = APIEndpoint(path: "/api/client/me", method: .GET)
            let me: ClientProfileResponse = try await apiClient.request(endpoint)
            customers = me.customers
            persona = me.persona
            reconcileSelection(preferred: me.activeCustomer)
        } catch {
            customers = []
            loadError = APIErrorMapper().map(error: error).errorDescription
        }
    }

    private func reconcileSelection(preferred: ActiveCustomer?) {
        let ids = Set(customers.map(\.id))
        if let sel = selectedCustomerId, ids.contains(sel) { return }
        if let p = preferred, ids.contains(p.id) {
            selectedCustomerId = p.id
            return
        }
        selectedCustomerId = customers.first?.id
    }
}
