import XCTest
@testable import Orda_Control

@MainActor
final class HomeViewModelTests: XCTestCase {
    func testLoadSuccessClearsError() async {
        let service = HomeServiceMock()
        let viewModel = HomeViewModel(service: service)
        let api = APIClient(config: .testHome)

        await viewModel.load(apiClient: api)

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.nearestBooking)
    }

    func testPointsToNextTierUsesCustomer() {
        let service = HomeServiceMock()
        let vm = HomeViewModel(service: service)
        let customer = ActiveCustomer(id: "1", companyId: "c1", name: "Иван", loyaltyPoints: 100, visitsCount: 3)
        XCTAssertEqual(vm.pointsToNextTier(for: customer), 400)
    }
}

private extension AppConfig {
    static var testHome: AppConfig {
        AppConfig(
            environment: .development,
            apiBaseURL: URL(string: "https://example.invalid")!,
            supabaseURL: URL(string: "https://example.supabase.co")!,
            supabaseAnonKey: "k",
            passwordResetRedirectURL: "orda-control://auth/reset-password"
        )
    }
}

private final class HomeServiceMock: HomeServicing {
    func fetchNearestBooking() async throws -> Booking? { nil }
    func fetchPointsSummary() async throws -> PointsSummary? { nil }
}
