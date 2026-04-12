import XCTest
@testable import Orda_Control

@MainActor
final class CustomersRegressionTests: XCTestCase {
    func testCustomersLoadTimeoutShowsRussianNetworkError() async {
        let vm = AdminListModuleViewModel<AdminCustomer>(loadAction: {
            throw APIError.timeout
        })

        await vm.load()

        XCTAssertEqual(vm.errorMessage, "Ошибка сети. Повторите попытку.")
        XCTAssertFalse(vm.isLoading)
    }

    func testCustomersRetryAfterFailureLoadsData() async {
        let loader = FlakyCustomersLoader()
        let vm = AdminListModuleViewModel<AdminCustomer>(loadAction: {
            try await loader.load()
        })

        await vm.load()
        XCTAssertEqual(vm.errorMessage, "Ошибка сети. Повторите попытку.")
        XCTAssertEqual(vm.items.count, 0)

        await vm.load() // retry action equivalent
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.items.count, 1)
        XCTAssertEqual(vm.items.first?.name, "Клиент A")
    }

    func testOnboardingErrorMapperUsesRussianMessages() {
        XCTAssertEqual(
            OnboardingErrorMapper.message(from: APIError.validation(message: "email-not-confirmed")),
            "Подтвердите email через письмо, затем завершите регистрацию."
        )
        XCTAssertEqual(
            OnboardingErrorMapper.message(from: APIError.forbidden),
            "Нет доступа для этой роли."
        )
        XCTAssertEqual(
            OnboardingErrorMapper.message(from: APIError.unauthorized),
            "Сессия истекла. Войдите снова."
        )
    }
}

@MainActor
private final class FlakyCustomersLoader {
    private var attempt = 0

    func load() async throws -> [AdminCustomer] {
        attempt += 1
        if attempt == 1 {
            throw APIError.timeout
        }
        let json = """
        { "id": "c1", "company_id": "cmp1", "name": "Клиент A", "loyalty_points": 0, "total_spent": 0, "visits_count": 0, "is_active": true }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let model = try decoder.decode(AdminCustomer.self, from: Data(json.utf8))
        return [model]
    }
}
