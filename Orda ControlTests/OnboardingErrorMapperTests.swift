import XCTest
@testable import Orda_Control

final class OnboardingErrorMapperTests: XCTestCase {
    func testEmailNotConfirmedWithUnderscoreMappedToFriendlyText() {
        let message = OnboardingErrorMapper.message(from: APIError.validation(message: "email_not_confirmed"))
        XCTAssertTrue(message.contains("Подтвердите email"))
    }

    func testEmailNotConfirmedWithDashMappedToFriendlyText() {
        let message = OnboardingErrorMapper.message(from: APIError.validation(message: "email-not-confirmed"))
        XCTAssertTrue(message.contains("Подтвердите email"))
    }

    func testNetworkErrorsMappedToRetryText() {
        XCTAssertEqual(
            OnboardingErrorMapper.message(from: APIError.networkUnavailable),
            "Ошибка сети. Повторите попытку."
        )
        XCTAssertEqual(
            OnboardingErrorMapper.message(from: APIError.timeout),
            "Ошибка сети. Повторите попытку."
        )
    }

    func testCancelledRequestMapsToRetryHint() {
        let message = OnboardingErrorMapper.message(from: APIError.validation(message: "cancelled"))
        XCTAssertTrue(message.contains("прерван"))
    }
}
