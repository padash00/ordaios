import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var nearestBooking: Booking?
    @Published private(set) var pointsSummary: PointsSummary?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let service: HomeServicing

    init(service: HomeServicing) {
        self.service = service
    }

    /// Профиль грузится в `ClientProfileStore`; здесь только ближайшая бронь и сводка баллов.
    func load(apiClient: APIClient) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let booking = service.fetchNearestBooking()
            async let points = service.fetchPointsSummary()
            nearestBooking = try await booking
            pointsSummary = try await points
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
        }
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
