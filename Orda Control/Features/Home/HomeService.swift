import Foundation

protocol HomeServicing {
    func fetchNearestBooking() async throws -> Booking?
    func fetchPointsSummary() async throws -> PointsSummary?
}

extension HomeServicing {
    func fetchNearestBooking() async throws -> Booking? { nil }
    func fetchPointsSummary() async throws -> PointsSummary? { nil }
}

final class HomeService: HomeServicing {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchNearestBooking() async throws -> Booking? {
        let endpoint = APIEndpoint(path: "/api/client/bookings?limit=20&offset=0", method: .GET)
        let response: BookingsResponse = try await apiClient.request(endpoint)
        return response.bookings
            .filter {
                $0.startsAt >= Date()
                    && !["cancelled", "rejected", "completed", "done"].contains($0.status.lowercased())
            }
            .sorted { $0.startsAt < $1.startsAt }
            .first
    }

    func fetchPointsSummary() async throws -> PointsSummary? {
        let endpoint = APIEndpoint(path: "/api/client/points?limit=1&offset=0", method: .GET)
        let response: PointsResponse = try await apiClient.request(endpoint)
        return response.summary
    }
}
