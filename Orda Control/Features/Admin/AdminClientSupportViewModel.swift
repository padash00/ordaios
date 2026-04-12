import Foundation
import Combine

@MainActor
final class AdminClientSupportViewModel: ObservableObject {
    private let pageSize = 25
    @Published private(set) var tickets: [AdminSupportTicket] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var errorMessage: String?
    @Published var actionErrorMessage: String?
    @Published private(set) var hasMore = false

    private let service: AdminClientSupportServicing
    private let canSetStatus: Bool
    private var nextOffset: Int?

    init(service: AdminClientSupportServicing, canSetStatus: Bool) {
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
            let response = try await service.fetchTickets(limit: pageSize, offset: nextOffset ?? 0)
            let sorted = response.requests.sorted { $0.createdAt > $1.createdAt }
            if reset {
                tickets = sorted
            } else {
                let existing = Set(tickets.map(\.id))
                tickets.append(contentsOf: sorted.filter { !existing.contains($0.id) })
                tickets.sort { $0.createdAt > $1.createdAt }
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

    func updateStatus(requestId: String, status: String, priority: String? = nil, assignedStaffId: String? = nil) async {
        guard canSetStatus else {
            actionErrorMessage = "Нет доступа для этой роли."
            return
        }
        actionErrorMessage = nil
        do {
            try await service.setStatus(
                requestId: requestId,
                status: status,
                priority: priority,
                assignedStaffId: assignedStaffId
            )
            await load(reset: true)
        } catch {
            actionErrorMessage = APIErrorMapper().map(error: error).errorDescription
        }
    }

    func filteredTickets(query: String, status: String) -> [AdminSupportTicket] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return tickets.filter { ticket in
            let byStatus = status == "Все" || ticket.status.lowercased() == status.lowercased()
            let byText = text.isEmpty
                || (ticket.customerName ?? "").lowercased().contains(text)
                || ticket.message.lowercased().contains(text)
            return byStatus && byText
        }
    }
}
