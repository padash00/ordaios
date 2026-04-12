import XCTest
@testable import Orda_Control

final class RoleParityMatrixTests: XCTestCase {
    func testRolePrecedenceMatchesWebDefaultPathOrder() {
        let mixed = roleContext(
            isSuperAdmin: false, isStaff: true, isOperator: true, isCustomer: true,
            persona: "staff", staffRole: "manager", defaultPath: ""
        )
        XCTAssertEqual(AppShellResolver.resolve(from: mixed), .staff)
    }

    func testCustomerDefaultPathNeverLeaksAdminShell() {
        let role = roleContext(
            isSuperAdmin: false, isStaff: false, isOperator: false, isCustomer: true,
            persona: "customer", staffRole: nil, defaultPath: "/client/bookings"
        )
        XCTAssertEqual(AppShellResolver.resolve(from: role), .client)
    }

    func testOperatorDefaultPathNeverLeaksClientShell() {
        let role = roleContext(
            isSuperAdmin: false, isStaff: false, isOperator: true, isCustomer: false,
            persona: "operator", staffRole: nil, defaultPath: "/operator/tasks"
        )
        XCTAssertEqual(AppShellResolver.resolve(from: role), .operatorRole)
    }

    func testSuperAdminShellAndTabsAndModuleVisibility() {
        let role = roleContext(
            isSuperAdmin: true, isStaff: true, isOperator: false, isCustomer: false,
            persona: "super_admin", staffRole: "owner", defaultPath: "/dashboard"
        )

        XCTAssertEqual(AppShellResolver.resolve(from: role), .admin)
        XCTAssertEqual(SuperAdminTab.from(defaultPath: role.defaultPath), .dashboard)
        XCTAssertTrue(ModuleAccessMatrix.isVisible(.finance, role: role))
        XCTAssertTrue(CapabilityMatrix.capabilities(for: role).contains(.adminCustomersWrite))
    }

    func testStaffOwnerParity() {
        let role = roleContext(
            isSuperAdmin: false, isStaff: true, isOperator: false, isCustomer: false,
            persona: "staff", staffRole: "owner", defaultPath: "/income"
        )
        let caps = CapabilityMatrix.capabilities(for: role)

        XCTAssertEqual(AppShellResolver.resolve(from: role), .staff)
        XCTAssertEqual(StaffTab.from(defaultPath: role.defaultPath, capabilities: caps, staffRole: "owner"), .finance)
        XCTAssertTrue(ModuleAccessMatrix.isVisible(.operators, role: role))
        XCTAssertTrue(caps.contains(.adminIncomesWrite))
        XCTAssertTrue(caps.contains(.adminInventoryWrite))
        XCTAssertTrue(caps.contains(.adminReportsRead))
        XCTAssertTrue(caps.contains(.adminKPIRead))
        XCTAssertTrue(ModuleAccessMatrix.isVisible(.inventory, role: role))
        XCTAssertFalse(caps.contains(.clientBookings))
    }

    func testStaffManagerParity() {
        let role = roleContext(
            isSuperAdmin: false, isStaff: true, isOperator: false, isCustomer: false,
            persona: "staff", staffRole: "manager", defaultPath: "/tasks"
        )
        let caps = CapabilityMatrix.capabilities(for: role)

        XCTAssertEqual(AppShellResolver.resolve(from: role), .staff)
        XCTAssertEqual(StaffTab.from(defaultPath: role.defaultPath, capabilities: caps, staffRole: "manager"), .dashboard)
        XCTAssertTrue(ModuleAccessMatrix.isVisible(.tasks, role: role))
        XCTAssertTrue(caps.contains(.adminTasksWrite))
        XCTAssertTrue(caps.contains(.adminReportsRead))
        XCTAssertTrue(caps.contains(.adminKPIRead))
        XCTAssertFalse(caps.contains(.operatorTasks))
    }

    func testStaffTabOpensOperationsForShiftsDeepLink() {
        let role = roleContext(
            isSuperAdmin: false, isStaff: true, isOperator: false, isCustomer: false,
            persona: "staff", staffRole: "marketer", defaultPath: "/shifts"
        )
        let caps = CapabilityMatrix.capabilities(for: role)
        XCTAssertEqual(StaffTab.from(defaultPath: "/shifts", capabilities: caps, staffRole: "marketer"), .operations)
    }

    func testStaffMarketerParityBlockedWrite() {
        let role = roleContext(
            isSuperAdmin: false, isStaff: true, isOperator: false, isCustomer: false,
            persona: "staff", staffRole: "marketer", defaultPath: "/welcome"
        )
        let caps = CapabilityMatrix.capabilities(for: role)

        XCTAssertEqual(AppShellResolver.resolve(from: role), .staff)
        XCTAssertEqual(StaffTab.from(defaultPath: role.defaultPath, capabilities: caps, staffRole: "marketer"), .dashboard)
        XCTAssertTrue(ModuleAccessMatrix.isVisible(.tasks, role: role))
        XCTAssertTrue(ModuleAccessMatrix.isVisible(.shifts, role: role))
        XCTAssertTrue(ModuleAccessMatrix.isVisible(.clientBookings, role: role))
        XCTAssertFalse(ModuleAccessMatrix.isVisible(.analytics, role: role))
        XCTAssertFalse(ModuleAccessMatrix.isVisible(.income, role: role))
        XCTAssertFalse(ModuleAccessMatrix.isVisible(.inventory, role: role))
        XCTAssertFalse(caps.contains(.adminIncomesWrite))
        XCTAssertFalse(caps.contains(.adminKPIRead))
        XCTAssertFalse(caps.contains(.adminReportsRead))
        XCTAssertTrue(caps.contains(.adminTasksRead))
        XCTAssertTrue(caps.contains(.adminTasksWrite))
        XCTAssertTrue(caps.contains(.adminShiftsRead))
        XCTAssertFalse(caps.contains(.adminShiftsWrite))
    }

    func testOperatorParity() {
        let role = roleContext(
            isSuperAdmin: false, isStaff: false, isOperator: true, isCustomer: false,
            persona: "operator", staffRole: nil, defaultPath: "/operator-dashboard"
        )
        let caps = CapabilityMatrix.capabilities(for: role)

        XCTAssertEqual(AppShellResolver.resolve(from: role), .operatorRole)
        XCTAssertEqual(OperatorTab.from(defaultPath: role.defaultPath, capabilities: caps), .dashboard)
        XCTAssertTrue(ModuleAccessMatrix.isVisible(.tasks, role: role))
        XCTAssertTrue(ModuleAccessMatrix.isVisible(.operators, role: role))
        XCTAssertFalse(ModuleAccessMatrix.isVisible(.finance, role: role))
        XCTAssertTrue(caps.contains(.operatorTasks))
        XCTAssertTrue(caps.contains(.operatorTasksWrite))
        XCTAssertTrue(caps.contains(.operatorShiftsWrite))
        XCTAssertTrue(caps.contains(.operatorSalaryRead))
        XCTAssertTrue(caps.contains(.operatorProfileRead))
        XCTAssertFalse(caps.contains(.adminTasksWrite))
    }

    func testCustomerParityNoAdminLeak() {
        let role = roleContext(
            isSuperAdmin: false, isStaff: false, isOperator: false, isCustomer: true,
            persona: "customer", staffRole: nil, defaultPath: "/client"
        )
        let caps = CapabilityMatrix.capabilities(for: role)

        XCTAssertEqual(AppShellResolver.resolve(from: role), .client)
        XCTAssertFalse(ModuleAccessMatrix.isVisible(.finance, role: role))
        XCTAssertFalse(ModuleAccessMatrix.isVisible(.operators, role: role))
        XCTAssertTrue(caps.contains(.clientHome))
        XCTAssertFalse(caps.contains(.adminClientBookingsReview))
    }

    private func roleContext(
        isSuperAdmin: Bool,
        isStaff: Bool,
        isOperator: Bool,
        isCustomer: Bool,
        persona: String,
        staffRole: String?,
        defaultPath: String
    ) -> SessionRoleContext {
        SessionRoleContext(
            isSuperAdmin: isSuperAdmin,
            isStaff: isStaff,
            isOperator: isOperator,
            isCustomer: isCustomer,
            persona: persona,
            staffRole: staffRole,
            roleLabel: nil,
            defaultPath: defaultPath,
            organizations: nil,
            activeOrganization: nil,
            activeSubscription: nil,
            rolePermissionOverrides: nil
        )
    }
}
