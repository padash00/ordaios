import XCTest
@testable import Orda_Control

final class ContractFixtureCoverageTests: XCTestCase {
    private var root: [String: Any] = [:]

    override func setUpWithError() throws {
        let data = try TestFixtureLoader.contractsFixtureJSON()
        root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testRequiredEndpointsExistInFixturePack() {
        let required = [
            "api/auth/session-role",
            "api/public/client/options",
            "api/public/client/register",
            "api/admin/customers",
            "api/admin/incomes",
            "api/admin/expenses",
            "api/admin/shifts",
            "api/admin/tasks",
            "api/admin/operators",
            "api/admin/operators/profile",
            "api/admin/customers/history",
            "api/client/me",
            "api/client/bookings",
            "api/client/points",
            "api/client/support"
        ]

        for endpoint in required {
            XCTAssertNotNil(root[endpoint], "Missing fixture section for \(endpoint)")
        }
    }

    func testSessionRoleFixturesDecodeToRoleContext() throws {
        let map = try XCTUnwrap(root["api/auth/session-role"] as? [String: Any])
        for variant in ["super_admin", "staff_manager", "marketer", "operator", "customer"] {
            let payload = try data(from: map[variant], name: variant)
            _ = try JSONDecoder().decode(SessionRoleContext.self, from: payload)
        }
    }

    func testPublicOptionsFixturesDecode() throws {
        let map = try XCTUnwrap(root["api/public/client/options"] as? [String: Any])
        for variant in ["flat", "data_envelope"] {
            let payload = try data(from: map[variant], name: variant)
            _ = try JSONDecoder().decode(ClientRegistrationOptionsResponse.self, from: payload)
        }
    }

    func testCustomersEnvelopeVariantsDecode() throws {
        let map = try XCTUnwrap(root["api/admin/customers"] as? [String: Any])
        let okData = try data(from: map["ok_data"], name: "ok_data")
        let rawList = try data(from: map["raw_list"], name: "raw_list")
        let lossy = try data(from: map["lossy_bad_item"], name: "lossy_bad_item")

        let d1 = try JSONDecoder().decode(DataListResponse<AdminCustomer>.self, from: okData)
        let d2 = try JSONDecoder().decode(DataListResponse<AdminCustomer>.self, from: rawList)
        let d3 = try JSONDecoder().decode(DataListResponse<AdminCustomer>.self, from: lossy)

        XCTAssertEqual(d1.data.count, 2)
        XCTAssertEqual(d2.data.count, 2)
        XCTAssertEqual(d3.data.count, 1)
    }

    private func data(from value: Any?, name: String) throws -> Data {
        guard let value else {
            throw NSError(domain: "fixture", code: 100, userInfo: [NSLocalizedDescriptionKey: "Missing fixture \(name)"])
        }
        return try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    }
}
