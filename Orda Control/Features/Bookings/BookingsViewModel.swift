import Foundation
import Combine

@MainActor
final class BookingsViewModel: ObservableObject {
    private let pageSize = 20
    @Published private(set) var bookings: [Booking] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var errorMessage: String?
    @Published var isCreating = false
    @Published var creationErrorMessage: String?
    @Published private(set) var cancellingBookingId: String?
    @Published private(set) var repeatingBookingId: String?
    @Published private(set) var hasMore = false

    private var nextOffset: Int?

    private let service: BookingServicing
    private let profileStore: ClientProfileStore

    init(service: BookingServicing, profileStore: ClientProfileStore) {
        self.service = service
        self.profileStore = profileStore
    }

    func load(reset: Bool = true) async {
        if reset {
            isLoading = true
            errorMessage = nil
            nextOffset = 0
        } else {
            guard hasMore, !isLoadingMore, nextOffset != nil else { return }
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
            let offset = reset ? 0 : (nextOffset ?? 0)
            let response = try await service.fetchBookings(limit: pageSize, offset: offset)
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

    func createBooking(startsAt: Date, notes: String?, companyId: String? = nil) async -> Bool {
        creationErrorMessage = nil
        isCreating = true
        defer { isCreating = false }

        let trimmedOverride = (companyId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedCompany = trimmedOverride.isEmpty ? profileStore.selectedCompanyId : trimmedOverride

        do {
            try await service.createBooking(startsAt: startsAt, notes: notes, companyId: resolvedCompany)
            await load(reset: true)
            return true
        } catch {
            creationErrorMessage = APIErrorMapper().map(error: error).errorDescription
            return false
        }
    }

    func filteredBookings(status: String) -> [Booking] {
        guard status != "Все" else { return bookings }
        return bookings.filter { $0.status.lowercased() == status.lowercased() }
    }

    func canCancelBooking(_ booking: Booking, now: Date = Date()) -> Bool {
        let status = booking.status.lowercased()
        guard ["requested", "pending", "new", "confirmed"].contains(status) else { return false }
        let minCancellationTime = booking.startsAt.addingTimeInterval(-24 * 60 * 60)
        return now <= minCancellationTime
    }

    func cancelBooking(_ booking: Booking) async -> Bool {
        guard canCancelBooking(booking) else {
            errorMessage = "Отмена доступна не позднее чем за 24 часа до начала."
            return false
        }
        cancellingBookingId = booking.id
        defer { cancellingBookingId = nil }
        do {
            try await service.cancelBooking(bookingId: booking.id)
            await load(reset: true)
            return true
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
            return false
        }
    }

    var lastRepeatCandidate: Booking? {
        bookings
            .filter { booking in
                booking.startsAt < Date()
                    && !["cancelled", "rejected"].contains(booking.status.lowercased())
            }
            .sorted { $0.startsAt > $1.startsAt }
            .first
    }

    func suggestedRepeatDate(for booking: Booking, now: Date = Date()) -> Date {
        let calendar = Calendar.current
        var candidate = booking.startsAt
        while candidate < now.addingTimeInterval(15 * 60) {
            candidate = calendar.date(byAdding: .day, value: 7, to: candidate) ?? candidate.addingTimeInterval(7 * 24 * 60 * 60)
        }
        return candidate
    }

    func repeatBooking(_ booking: Booking) async -> Bool {
        repeatingBookingId = booking.id
        defer { repeatingBookingId = nil }
        let start = suggestedRepeatDate(for: booking)
        return await createBooking(startsAt: start, notes: booking.notes, companyId: booking.companyId)
    }
}
