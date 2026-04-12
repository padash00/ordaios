import Foundation

protocol BookingServicing {
    func fetchBookings(limit: Int, offset: Int) async throws -> BookingsResponse
    func createBooking(startsAt: Date, notes: String?, companyId: String?) async throws
    func cancelBooking(bookingId: String) async throws
}

final class BookingService: BookingServicing {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchBookings(limit: Int, offset: Int) async throws -> BookingsResponse {
        let safeLimit = max(1, limit)
        let safeOffset = max(0, offset)
        let endpoint = APIEndpoint(path: "/api/client/bookings?limit=\(safeLimit)&offset=\(safeOffset)", method: .GET)
        return try await apiClient.request(endpoint)
    }

    func createBooking(startsAt: Date, notes: String?, companyId: String?) async throws {
        let endpoint = APIEndpoint(path: "/api/client/bookings", method: .POST)
        let startsAtString = AppDateFormatter.iso8601.string(from: startsAt)
        let trimmedCompany = companyId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cid = (trimmedCompany?.isEmpty == false) ? trimmedCompany : nil
        let body = CreateBookingRequest(
            startsAt: startsAtString,
            endsAt: nil,
            notes: notes?.isEmpty == true ? nil : notes,
            companyId: cid
        )
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: body)
    }

    func cancelBooking(bookingId: String) async throws {
        let endpoint = APIEndpoint(path: "/api/client/bookings", method: .POST)
        let body = CancelBookingRequest(action: "cancelBooking", bookingId: bookingId)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: body)
    }
}
