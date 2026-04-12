import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var nearestBooking: Booking?
    @Published private(set) var pointsSummary: PointsSummary?
    @Published private(set) var isLoading = false
    /// Неблокирующее предупреждение: главная остаётся доступной, если не подтянулись только брони или баллы.
    @Published private(set) var loadNotice: String?

    private let service: HomeServicing

    init(service: HomeServicing) {
        self.service = service
    }

    /// Профиль грузится в `ClientProfileStore`; здесь только ближайшая бронь и сводка баллов.
    func load(apiClient: APIClient) async {
        isLoading = true
        loadNotice = nil
        defer { isLoading = false }

        var notices: [String] = []

        do {
            nearestBooking = try await service.fetchNearestBooking()
        } catch {
            nearestBooking = nil
            notices.append(bookingLoadUserMessage(for: APIErrorMapper().map(error: error)))
        }

        do {
            pointsSummary = try await service.fetchPointsSummary()
        } catch {
            pointsSummary = nil
            notices.append(pointsLoadUserMessage(for: APIErrorMapper().map(error: error)))
        }

        loadNotice = notices.isEmpty ? nil : notices.joined(separator: "\n")
    }

    private func bookingLoadUserMessage(for error: APIError) -> String {
        switch error {
        case .validation(let m), .server(let m), .unknown(let m):
            let t = m.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { break }
            return "Брони: \(t)"
        default:
            break
        }
        return "Брони: не удалось загрузить. Откройте вкладку «Брони» или потяните экран вниз."
    }

    private func pointsLoadUserMessage(for error: APIError) -> String {
        switch error {
        case .validation(let m), .server(let m), .unknown(let m):
            let t = m.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { break }
            return "Баллы: \(t)"
        default:
            break
        }
        return "Баллы: не удалось обновить с сервера — на карточке ниже показаны данные из профиля."
    }

    func pointsToNextTier(for customer: ActiveCustomer?) -> Int {
        let points = pointsSummary?.points ?? customer?.loyaltyPoints ?? 0
        if points < 500 { return 500 - points }
        if points < 2000 { return 2000 - points }
        return 0
    }

    func nextTierTitle(for customer: ActiveCustomer?) -> String? {
        let points = pointsSummary?.points ?? customer?.loyaltyPoints ?? 0
        if points < 500 { return "Gold" }
        if points < 2000 { return "Platinum" }
        return nil
    }
}
