import Foundation
import Combine

struct LoyaltyTier {
    let key: String
    let title: String
    let minPoints: Int
    let maxPointsExclusive: Int?

    static let all: [LoyaltyTier] = [
        LoyaltyTier(key: "silver", title: "Silver", minPoints: 0, maxPointsExclusive: 500),
        LoyaltyTier(key: "gold", title: "Gold", minPoints: 500, maxPointsExclusive: 2000),
        LoyaltyTier(key: "platinum", title: "Platinum", minPoints: 2000, maxPointsExclusive: nil),
    ]
}

struct LoyaltyRewardOption: Identifiable {
    let id: String
    let title: String
    let pointsCost: Int
    let minTierKey: String
    let subtitle: String
}

@MainActor
final class PointsViewModel: ObservableObject {
    private let pageSize = 20
    @Published private(set) var summary: PointsSummary?
    @Published private(set) var history: [PointsHistoryItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMoreHistory = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var redeemingRewardId: String?
    @Published var redemptionMessage: String?
    @Published private(set) var hasMoreHistory = false

    private var nextHistoryOffset: Int?

    private let service: PointsServicing

    init(service: PointsServicing) {
        self.service = service
    }

    var totalEarned: Int {
        history.reduce(0) { $0 + ($1.loyaltyPointsEarned ?? 0) }
    }

    var primaryCustomerId: String {
        summary?.customerId ?? history.compactMap(\.customerId).first ?? "unknown"
    }

    var currentTier: LoyaltyTier {
        let points = summary?.points ?? 0
        return LoyaltyTier.all.first(where: { tier in
            if let upper = tier.maxPointsExclusive {
                return points >= tier.minPoints && points < upper
            }
            return points >= tier.minPoints
        }) ?? LoyaltyTier.all[0]
    }

    var nextTier: LoyaltyTier? {
        guard let idx = LoyaltyTier.all.firstIndex(where: { $0.key == currentTier.key }) else { return nil }
        let nextIdx = idx + 1
        guard nextIdx < LoyaltyTier.all.count else { return nil }
        return LoyaltyTier.all[nextIdx]
    }

    var pointsToNextTier: Int {
        guard let nextTier else { return 0 }
        let points = summary?.points ?? 0
        return max(0, nextTier.minPoints - points)
    }

    var tierProgress: Double {
        let points = summary?.points ?? 0
        let tier = currentTier
        guard let upper = tier.maxPointsExclusive else { return 1.0 }
        let span = max(1, upper - tier.minPoints)
        let progress = Double(points - tier.minPoints) / Double(span)
        return max(0, min(1, progress))
    }

    var rewardOptions: [LoyaltyRewardOption] {
        [
            LoyaltyRewardOption(
                id: "discount-5",
                title: "Скидка 5%",
                pointsCost: 300,
                minTierKey: "silver",
                subtitle: "Применить к следующему заказу"
            ),
            LoyaltyRewardOption(
                id: "drink",
                title: "Бесплатный напиток",
                pointsCost: 550,
                minTierKey: "gold",
                subtitle: "Доступно на уровне Gold и выше"
            ),
            LoyaltyRewardOption(
                id: "discount-10",
                title: "Скидка 10%",
                pointsCost: 900,
                minTierKey: "gold",
                subtitle: "Повышенная выгода для активных клиентов"
            ),
            LoyaltyRewardOption(
                id: "vip-table",
                title: "VIP-бронирование",
                pointsCost: 1500,
                minTierKey: "platinum",
                subtitle: "Приоритетный стол и подтверждение"
            )
        ]
    }

    func canRedeem(_ reward: LoyaltyRewardOption) -> Bool {
        guard hasTierAccess(reward.minTierKey) else { return false }
        return (summary?.points ?? 0) >= reward.pointsCost
    }

    func hasTierAccess(_ tierKey: String) -> Bool {
        guard
            let current = LoyaltyTier.all.firstIndex(where: { $0.key == currentTier.key }),
            let required = LoyaltyTier.all.firstIndex(where: { $0.key == tierKey })
        else { return false }
        return current >= required
    }

    func load(reset: Bool = true) async {
        if reset {
            isLoading = true
            errorMessage = nil
            nextHistoryOffset = 0
        } else {
            guard hasMoreHistory, !isLoadingMoreHistory else { return }
            isLoadingMoreHistory = true
        }
        defer {
            if reset {
                isLoading = false
            } else {
                isLoadingMoreHistory = false
            }
        }

        do {
            let response = try await service.fetchPoints(limit: pageSize, offset: nextHistoryOffset ?? 0)
            summary = response.summary
            let sorted = response.history.sorted {
                ($0.saleDate ?? "") > ($1.saleDate ?? "")
            }
            if reset {
                history = sorted
            } else {
                let existing = Set(history.map(\.id))
                history.append(contentsOf: sorted.filter { !existing.contains($0.id) })
                history.sort { ($0.saleDate ?? "") > ($1.saleDate ?? "") }
            }
            hasMoreHistory = response.hasMore
            nextHistoryOffset = response.nextOffset
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
        }
    }

    func loadMoreHistory() async {
        await load(reset: false)
    }

    func redeem(_ reward: LoyaltyRewardOption) async {
        guard canRedeem(reward) else { return }
        redeemingRewardId = reward.id
        redemptionMessage = nil
        errorMessage = nil
        defer { redeemingRewardId = nil }

        do {
            let response = try await service.redeemPoints(reward: reward)
            summary = response.summary
            if let redemption = response.redemption {
                history.removeAll { $0.id == redemption.id }
                history.insert(redemption, at: 0)
            }
            redemptionMessage = "Награда \"\(reward.title)\" успешно обменяна."
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
        }
    }
}
