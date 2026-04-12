import XCTest
@testable import Orda_Control

final class ClientProfileDecodingTests: XCTestCase {
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    func testClientMeDecodesMultipleCustomersWithCompanyId() throws {
        let json = """
        {
          "ok": true,
          "persona": "customer",
          "customers": [
            {
              "id": "cust-a",
              "company_id": "11111111-1111-1111-1111-111111111111",
              "name": "Клуб А",
              "phone": "+77001112233",
              "loyalty_points": 10,
              "visits_count": 2,
              "total_spent": "100.5"
            },
            {
              "id": "cust-b",
              "company_id": "22222222-2222-2222-2222-222222222222",
              "name": "Клуб B",
              "loyalty_points": 5,
              "visits_count": 1
            }
          ],
          "activeCustomer": {
            "id": "cust-a",
            "company_id": "11111111-1111-1111-1111-111111111111",
            "name": "Клуб А",
            "loyalty_points": 10,
            "visits_count": 2
          }
        }
        """

        let me = try decoder.decode(ClientProfileResponse.self, from: Data(json.utf8))
        XCTAssertEqual(me.customers.count, 2)
        XCTAssertEqual(me.customers[0].companyId, "11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(me.customers[1].id, "cust-b")
        XCTAssertEqual(me.activeCustomer?.id, "cust-a")
    }

    func testBookingDecodesCompanyId() throws {
        let json = """
        {
          "id": "b1",
          "company_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
          "customer_id": "cust-a",
          "starts_at": "2026-05-01T12:00:00Z",
          "ends_at": "2026-05-01T14:00:00Z",
          "status": "requested",
          "notes": "ok",
          "created_at": "2026-04-01T10:00:00Z"
        }
        """
        let booking = try decoder.decode(Booking.self, from: Data(json.utf8))
        XCTAssertEqual(booking.companyId, "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
        XCTAssertEqual(booking.customerId, "cust-a")
    }

    func testCreateBookingRequestEncodesCompanyId() throws {
        let body = CreateBookingRequest(
            startsAt: "2026-05-01T12:00:00.000Z",
            endsAt: nil,
            notes: "hi",
            companyId: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
        )
        let data = try encoder.encode(body)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(obj?["companyId"] as? String, "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")
        XCTAssertEqual(obj?["startsAt"] as? String, "2026-05-01T12:00:00.000Z")
    }

    func testCreateSupportRequestEncodesOptionalCompanyId() throws {
        let withCompany = CreateSupportRequest(message: "help", companyId: "cccccccc-cccc-cccc-cccc-cccccccccccc")
        let d1 = try encoder.encode(withCompany)
        let o1 = try JSONSerialization.jsonObject(with: d1) as? [String: Any]
        XCTAssertEqual(o1?["message"] as? String, "help")
        XCTAssertEqual(o1?["companyId"] as? String, "cccccccc-cccc-cccc-cccc-cccccccccccc")

        let without = CreateSupportRequest(message: "only")
        let d2 = try encoder.encode(without)
        let o2 = try JSONSerialization.jsonObject(with: d2) as? [String: Any]
        XCTAssertNil(o2?["companyId"])
    }

    func testApiErrorMapperSurfacesCompanyIdRequired() {
        let mapped = APIErrorMapper().map(statusCode: 400, message: "company-id-required")
        guard case .validation(let msg) = mapped else {
            XCTFail("expected validation")
            return
        }
        XCTAssertTrue(msg.contains("Главная"))
    }

    func testApiErrorMapperSurfacesCompanyNotInProfile() {
        let mapped = APIErrorMapper().map(statusCode: 400, message: "company-not-in-profile")
        guard case .validation(let msg) = mapped else {
            XCTFail("expected validation")
            return
        }
        XCTAssertTrue(msg.lowercased().contains("профил"))
    }
}
