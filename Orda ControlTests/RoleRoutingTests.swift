import XCTest
@testable import Orda_Control

final class RoleRoutingTests: XCTestCase {
    func testSuperAdminRoutesToAdminShell() {
        let ctx = SessionRoleContext(
            isSuperAdmin: true,
            isStaff: false,
            isOperator: false,
            isCustomer: false,
            persona: "super_admin",
            staffRole: nil,
            roleLabel: "Super Admin",
            defaultPath: "/admin",
            organizations: nil,
            activeOrganization: nil,
            activeSubscription: nil,
            rolePermissionOverrides: nil
        )
        XCTAssertEqual(ctx.appShell, .admin)
        XCTAssertTrue(CapabilityMatrix.capabilities(for: ctx).contains(.adminClientBookingsSetStatus))
    }

    func testOperatorRoutesToOperatorShell() {
        let ctx = SessionRoleContext(
            isSuperAdmin: false,
            isStaff: false,
            isOperator: true,
            isCustomer: false,
            persona: "operator",
            staffRole: nil,
            roleLabel: "Operator",
            defaultPath: "/operator/support",
            organizations: nil,
            activeOrganization: nil,
            activeSubscription: nil,
            rolePermissionOverrides: nil
        )
        XCTAssertEqual(ctx.appShell, .operatorRole)
        let caps = CapabilityMatrix.capabilities(for: ctx)
        XCTAssertTrue(caps.contains(.operatorDashboard))
        XCTAssertTrue(caps.contains(.operatorTasks))
        XCTAssertFalse(caps.contains(.adminClientBookingsSetStatus))
    }

    func testDefaultPathClientWinsWhenClientPathProvided() {
        let ctx = SessionRoleContext(
            isSuperAdmin: false,
            isStaff: false,
            isOperator: false,
            isCustomer: true,
            persona: "customer",
            staffRole: nil,
            roleLabel: "Client",
            defaultPath: "/client/home",
            organizations: nil,
            activeOrganization: nil,
            activeSubscription: nil,
            rolePermissionOverrides: nil
        )
        XCTAssertEqual(AppShellResolver.resolve(from: ctx), .client)
    }
}
