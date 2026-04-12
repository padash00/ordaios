import XCTest
@testable import Orda_Control

@MainActor
final class PersonaViewModelsTests: XCTestCase {
    func testSuperAdminBookingsViewModelCanUpdateStatus() async {
        let service = AdminBookingsServiceMock()
        let vm = AdminClientBookingsViewModel(service: service, canSetStatus: true)
        await vm.updateStatus(bookingId: "b1", status: "confirmed")
        XCTAssertEqual(service.lastUpdatedBookingId, "b1")
        XCTAssertEqual(service.lastUpdatedStatus, "confirmed")
    }

    func testStaffMarketerBookingsViewModelCannotUpdateStatus() async {
        let service = AdminBookingsServiceMock()
        let vm = AdminClientBookingsViewModel(service: service, canSetStatus: false)
        await vm.updateStatus(bookingId: "b1", status: "confirmed")
        XCTAssertNil(service.lastUpdatedBookingId)
        XCTAssertEqual(vm.actionErrorMessage, "Нет доступа для этой роли.")
    }

    func testOperatorSupportViewModelCanUpdateStatus() async {
        let service = AdminSupportServiceMock()
        let vm = AdminClientSupportViewModel(service: service, canSetStatus: true)
        await vm.updateStatus(requestId: "r1", status: "closed")
        XCTAssertEqual(service.lastUpdatedRequestId, "r1")
        XCTAssertEqual(service.lastUpdatedStatus, "closed")
    }
}

private final class AdminBookingsServiceMock: AdminClientBookingsServicing {
    var lastUpdatedBookingId: String?
    var lastUpdatedStatus: String?

    func fetchBookings(limit: Int, offset: Int) async throws -> AdminBookingsResponse {
        throw URLError(.badServerResponse)
    }

    func setStatus(bookingId: String, status: String) async throws {
        lastUpdatedBookingId = bookingId
        lastUpdatedStatus = status
    }
}

private final class AdminSupportServiceMock: AdminClientSupportServicing {
    var lastUpdatedRequestId: String?
    var lastUpdatedStatus: String?

    func fetchTickets(limit: Int, offset: Int) async throws -> AdminSupportResponse {
        throw URLError(.badServerResponse)
    }

    func setStatus(requestId: String, status: String, priority: String?, assignedStaffId: String?) async throws {
        lastUpdatedRequestId = requestId
        lastUpdatedStatus = status
    }
}
