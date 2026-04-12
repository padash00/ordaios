import Foundation
import Combine

@MainActor
final class SupportViewModel: ObservableObject {
    private let pageSize = 20
    @Published private(set) var requests: [SupportRequestItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var errorMessage: String?
    @Published var sendErrorMessage: String?
    @Published var isSending = false
    @Published private(set) var hasMore = false

    private var nextOffset: Int?

    private let service: SupportServicing
    private let profileStore: ClientProfileStore

    init(service: SupportServicing, profileStore: ClientProfileStore) {
        self.service = service
        self.profileStore = profileStore
    }

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
            let response = try await service.fetchRequests(limit: pageSize, offset: nextOffset ?? 0)
            let sorted = response.requests.sorted { $0.createdAt > $1.createdAt }
            if reset {
                requests = sorted
            } else {
                let existing = Set(requests.map(\.id))
                requests.append(contentsOf: sorted.filter { !existing.contains($0.id) })
                requests.sort { $0.createdAt > $1.createdAt }
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

    func send(message: String) async -> Bool {
        sendErrorMessage = nil
        isSending = true
        defer { isSending = false }

        if message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sendErrorMessage = "Введите сообщение"
            return false
        }

        do {
            try await service.send(message: message, companyId: profileStore.selectedCompanyId)
            await load(reset: true)
            return true
        } catch {
            sendErrorMessage = APIErrorMapper().map(error: error).errorDescription
            return false
        }
    }

    func filteredRequests(status: String) -> [SupportRequestItem] {
        guard status != "Все" else { return requests }
        return requests.filter { $0.status.lowercased() == status.lowercased() }
    }
}
