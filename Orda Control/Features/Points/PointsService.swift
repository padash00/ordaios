import Foundation

protocol PointsServicing {
    func fetchPoints(limit: Int, offset: Int) async throws -> PointsResponse
    func redeemPoints(reward: LoyaltyRewardOption) async throws -> RedeemPointsResponse
}

final class PointsService: PointsServicing {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchPoints(limit: Int, offset: Int) async throws -> PointsResponse {
        let safeLimit = max(1, limit)
        let safeOffset = max(0, offset)
        let endpoint = APIEndpoint(path: "/api/client/points?limit=\(safeLimit)&offset=\(safeOffset)", method: .GET)
        return try await apiClient.request(endpoint)
    }

    func redeemPoints(reward: LoyaltyRewardOption) async throws -> RedeemPointsResponse {
        let endpoint = APIEndpoint(path: "/api/client/points", method: .POST)
        let body = RedeemPointsRequest(
            action: "redeemReward",
            rewardId: reward.id,
            rewardTitle: reward.title,
            pointsCost: reward.pointsCost,
            minTierKey: reward.minTierKey
        )
        return try await apiClient.request(endpoint, body: body)
    }
}
