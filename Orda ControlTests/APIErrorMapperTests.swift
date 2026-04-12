import XCTest
@testable import Orda_Control

final class APIErrorMapperTests: XCTestCase {
    private let mapper = APIErrorMapper()

    func testMapUnauthorizedStatusCode() {
        let error = mapper.map(statusCode: 401, message: nil)
        XCTAssertEqual(error, .unauthorized)
    }

    func testMapValidationStatusCode() {
        let error = mapper.map(statusCode: 422, message: "Ошибка валидации")
        XCTAssertEqual(error, .validation(message: "Ошибка валидации"))
    }

    func testMapForbiddenStatusCode() {
        let error = mapper.map(statusCode: 403, message: nil)
        XCTAssertEqual(error, .forbidden)
    }

    func testMapNetworkUnavailableFromURLError() {
        let error = mapper.map(error: URLError(.notConnectedToInternet))
        XCTAssertEqual(error, .networkUnavailable)
    }
}
