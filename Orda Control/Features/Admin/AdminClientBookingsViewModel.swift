import Foundation
import Combine

@MainActor
final class AdminClientBookingsViewModel: ObservableObject {
    private let pageSize = 25
    @Published private(set) var bookings: [AdminBooking] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var errorMessage: String?
    @Published var actionErrorMessage: String?
    @Published private(set) var hasMore = false

    private let service: AdminClientBookingsServicing
    private let canSetStatus: Bool
    private var nextOffset: Int?

    init(service: AdminClientBookingsServicing, canSetStatus: Bool) {
        self.service = service
        self.canSetStatus = canSetStatus
    }

    var canEditStatus: Bool { canSetStatus }

    func load(reset: Bool = true) async {
        if reset {
            isLoading = true
            errorMessage = nil
            nextOffset = 0
        } else {
            guard hasMore, !isLoadingMore else { return }
            isLoadingMore = true
        }
        defer {
            if reset {
                isLoading = false
            } else {
                isLoadingMore = false
            }
        }
        do {
            let response = try await service.fetchBookings(limit: pageSize, offset: nextOffset ?? 0)
            let sorted = response.bookings.sorted { $0.startsAt > $1.startsAt }
            if reset {
                bookings = sorted
            } else {
                let existing = Set(bookings.map(\.id))
                bookings.append(contentsOf: sorted.filter { !existing.contains($0.id) })
                bookings.sort { $0.startsAt > $1.startsAt }
            }
            hasMore = response.hasMore
            nextOffset = response.nextOffset
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
        }
    }

    func loadMore() async {
        await load(reset: false)
    }

    func updateStatus(bookingId: String, status: String) async {
        guard canSetStatus else {
            actionErrorMessage = "Нет доступа для этой роли."
            return
        }
        actionErrorMessage = nil
        do {
            try await service.setStatus(bookingId: bookingId, status: status)
            await load(reset: true)
        } catch {
            actionErrorMessage = APIErrorMapper().map(error: error).errorDescription
        }
    }

    func filteredBookings(query: String, status: String) -> [AdminBooking] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return bookings.filter { booking in
            let byStatus = status == "Все" || booking.status.lowercased() == status.lowercased()
            let byText = text.isEmpty
                || (booking.customerName ?? "").lowercased().contains(text)
                || (booking.notes ?? "").lowercased().contains(text)
            return byStatus && byText
        }
    }
}
