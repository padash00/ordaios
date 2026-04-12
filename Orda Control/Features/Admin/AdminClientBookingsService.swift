import Foundation

protocol AdminClientBookingsServicing {
    func fetchBookings(limit: Int, offset: Int) async throws -> AdminBookingsResponse
    func setStatus(bookingId: String, status: String) async throws
}

final class AdminClientBookingsService: AdminClientBookingsServicing {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchBookings(limit: Int, offset: Int) async throws -> AdminBookingsResponse {
        let safeLimit = max(1, limit)
        let safeOffset = max(0, offset)
        let endpoint = APIEndpoint(path: "/api/admin/client/bookings?limit=\(safeLimit)&offset=\(safeOffset)", method: .GET)
        return try await apiClient.request(endpoint)
    }

    func setStatus(bookingId: String, status: String) async throws {
        let endpoint = APIEndpoint(path: "/api/admin/client/bookings", method: .POST)
        let body = AdminBookingStatusRequest(action: "setStatus", bookingId: bookingId, status: status)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: body)
    }
}
