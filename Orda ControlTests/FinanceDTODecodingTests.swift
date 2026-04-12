import XCTest
@testable import Orda_Control

final class FinanceDTODecodingTests: XCTestCase {
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    func testAdminIncomeDecodesWhenAmountsAreStrings() throws {
        let json = """
        {
          "data": [
            {
              "id": "inc-1",
              "date": "2026-04-10",
              "company_id": "co-1",
              "operator_id": "op-1",
              "shift": "day",
              "zone": "A",
              "cash_amount": "1000.5",
              "kaspi_amount": "2000",
              "online_amount": "300.25",
              "card_amount": "99.75",
              "comment": "ok"
            }
          ]
        }
        """

        let response = try decoder.decode(DataListResponse<AdminIncome>.self, from: Data(json.utf8))
        XCTAssertEqual(response.data.count, 1)
        XCTAssertEqual(response.data[0].id, "inc-1")
        XCTAssertEqual(response.data[0].companyId, "co-1")
        XCTAssertEqual(response.data[0].cashAmount, 1000.5, accuracy: 0.001)
        XCTAssertEqual(response.data[0].total, 3400.5, accuracy: 0.001)
    }

    func testAdminIncomeDecodesWhenOptionalFieldsAreNull() throws {
        let json = """
        {
          "data": [
            {
              "id": "inc-2",
              "date": "2026-04-10",
              "company_id": null,
              "operator_id": null,
              "shift": null,
              "zone": null,
              "cash_amount": null,
              "kaspi_amount": null,
              "online_amount": null,
              "card_amount": null,
              "comment": null
            }
          ]
        }
        """

        let response = try decoder.decode(DataListResponse<AdminIncome>.self, from: Data(json.utf8))
        XCTAssertEqual(response.data.count, 1)
        XCTAssertEqual(response.data[0].id, "inc-2")
        XCTAssertEqual(response.data[0].companyId, "")
        XCTAssertEqual(response.data[0].total, 0, accuracy: 0.001)
    }

    func testAdminExpenseDecodesWhenCategoryIsNullAndAmountsAreStrings() throws {
        let json = """
        {
          "data": [
            {
              "id": "exp-1",
              "date": "2026-04-10",
              "company_id": "co-1",
              "operator_id": "op-1",
              "category": null,
              "cash_amount": "1200",
              "kaspi_amount": "800.5",
              "comment": "note",
              "attachment_url": null
            }
          ]
        }
        """

        let response = try decoder.decode(DataListResponse<AdminExpense>.self, from: Data(json.utf8))
        XCTAssertEqual(response.data.count, 1)
        XCTAssertEqual(response.data[0].id, "exp-1")
        XCTAssertEqual(response.data[0].category, "other")
        XCTAssertEqual(response.data[0].total, 2000.5, accuracy: 0.001)
    }

    func testAdminExpenseArrayEnvelopeAlsoDecodes() throws {
        let json = """
        [
          {
            "id": "exp-2",
            "date": "2026-04-10",
            "company_id": "co-1",
            "operator_id": "op-2",
            "category": "rent",
            "cash_amount": 5000,
            "kaspi_amount": 0,
            "comment": "monthly",
            "attachment_url": null
          }
        ]
        """

        let response = try decoder.decode(DataListResponse<AdminExpense>.self, from: Data(json.utf8))
        XCTAssertEqual(response.data.count, 1)
        XCTAssertEqual(response.data[0].categoryLabel, "Аренда")
    }

    func testAdminOperatorsDecodeWhenTelegramChatIdIsNumber() throws {
        let json = """
        {
          "data": [
            {
              "id": "op-1",
              "name": "Алибек",
              "short_name": "Али",
              "is_active": true,
              "role": "operator",
              "telegram_chat_id": 123456789
            }
          ]
        }
        """

        let response = try decoder.decode(DataListResponse<AdminOperator>.self, from: Data(json.utf8))
        XCTAssertEqual(response.data.count, 1)
        XCTAssertEqual(response.data[0].id, "op-1")
        XCTAssertEqual(response.data[0].telegramChatId, "123456789")
    }

    func testSalaryPaymentDecodesWithSnakeCaseJSON() throws {
        let json = """
        {
          "id": "pay-1",
          "payment_date": "2026-04-10",
          "cash_amount": 100,
          "kaspi_amount": 50,
          "total_amount": 150,
          "comment": null,
          "status": "posted",
          "created_at": "2026-04-10T00:00:00Z"
        }
        """

        let row = try decoder.decode(SalaryPayment.self, from: Data(json.utf8))
        XCTAssertEqual(row.id, "pay-1")
        XCTAssertEqual(row.paymentDate, "2026-04-10")
        XCTAssertEqual(row.cashAmount, 100, accuracy: 0.001)
        XCTAssertEqual(row.kaspiAmount, 50, accuracy: 0.001)
        XCTAssertEqual(row.totalAmount, 150, accuracy: 0.001)
    }

    func testAdminProfitabilityDecodesSnakeKeys() throws {
        let json = """
        {
          "revenue": 1000,
          "cost_of_goods": 200,
          "gross_profit": 800,
          "gross_margin": 0.8,
          "operating_expenses": 100,
          "ebitda": 700,
          "net_profit": 600,
          "net_margin": 0.6,
          "period": "2026-04",
          "breakdown": []
        }
        """

        let pl = try decoder.decode(AdminProfitabilityData.self, from: Data(json.utf8))
        XCTAssertEqual(pl.revenue, 1000, accuracy: 0.001)
        XCTAssertEqual(pl.costOfGoods, 200, accuracy: 0.001)
        XCTAssertEqual(pl.netProfit, 600, accuracy: 0.001)
    }

    func testSalaryOperatorRowDecodesNestedOperatorShape() throws {
        let json = """
        {
          "operator": {
            "id": "op-1",
            "name": "Тест",
            "short_name": "Т",
            "is_active": true
          },
          "week": {
            "id": "week-1",
            "gross_amount": 1,
            "bonus_amount": 0,
            "fine_amount": 0,
            "debt_amount": 0,
            "advance_amount": 0,
            "net_amount": 1,
            "paid_amount": 0,
            "remaining_amount": 1,
            "status": "open",
            "payments": [],
            "allocations": []
          }
        }
        """

        let row = try decoder.decode(SalaryOperatorRow.self, from: Data(json.utf8))
        XCTAssertEqual(row.id, "op-1")
        XCTAssertEqual(row.shortName, "Т")
        XCTAssertEqual(row.week.status, "open")
    }

    func testAdminCategoriesDecodeFromLegacyAliasPayload() throws {
        let json = """
        {
          "data": [
            {
              "id": "cat-1",
              "name": "Аренда",
              "type": "expense",
              "color": null,
              "parent_id": null
            }
          ]
        }
        """

        let response = try decoder.decode(DataListResponse<AdminCategory>.self, from: Data(json.utf8))
        XCTAssertEqual(response.data.count, 1)
        XCTAssertEqual(response.data[0].id, "cat-1")
        XCTAssertEqual(response.data[0].name, "Аренда")
        XCTAssertEqual(response.data[0].type, "expense")
    }

    func testPointDevicesDecodeFromCurrentServerShape() throws {
        let json = """
        {
          "companies": [
            { "id": "co-1", "name": "F16", "code": "F16" }
          ],
          "projects": [
            {
              "id": "pp-1",
              "name": "Astana Mall",
              "project_token": "tok_123",
              "point_mode": "gaming_club",
              "is_active": true,
              "last_seen_at": "2026-04-10T10:00:00.000Z",
              "feature_flags": { "shift_report": true, "income_report": true },
              "companies": [
                { "id": "co-1", "name": "F16", "code": "F16", "point_mode": "gaming_club" }
              ]
            }
          ]
        }
        """

        let response = try decoder.decode(PointDevicesResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.companies.count, 1)
        XCTAssertEqual(response.projects.count, 1)
        XCTAssertEqual(response.projects[0].mode, "gaming_club")
        XCTAssertEqual(response.projects[0].token, "tok_123")
        XCTAssertEqual(response.projects[0].companyAssignments.first?.companyId, "co-1")
    }

    func testPointDevicesDecodeFromOkDataEnvelope() throws {
        let json = """
        {
          "ok": true,
          "data": {
            "companies": [
              { "id": "co-1", "name": "F16", "code": "F16" }
            ],
            "projects": [
              {
                "id": "pp-1",
                "name": "Astana Mall",
                "project_token": "tok_123",
                "point_mode": "gaming_club",
                "is_active": true,
                "companies": [
                  { "id": "co-1", "name": "F16", "code": "F16" }
                ]
              }
            ]
          }
        }
        """

        let response = try decoder.decode(PointDevicesResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.companies.count, 1)
        XCTAssertEqual(response.projects.count, 1)
        XCTAssertEqual(response.projects[0].companyAssignments.first?.companyId, "co-1")
    }

    func testExpenseCategoryRowDecodesAccountingFields() throws {
        let json = """
        {
          "data": [
            {
              "id": "cat-2",
              "name": "Аренда",
              "accounting_group": "operating",
              "monthly_budget": "150000"
            }
          ]
        }
        """

        let response = try decoder.decode(DataListResponse<AdminCategory>.self, from: Data(json.utf8))
        XCTAssertEqual(response.data.count, 1)
        XCTAssertEqual(response.data[0].accountingGroup, "operating")
        XCTAssertEqual(response.data[0].monthlyBudget, 150_000, accuracy: 0.1)
    }
}
