import Foundation

// MARK: - Point Devices Models

struct PointDevicesResponse: Decodable {
    let companies: [PointDeviceCompany]
    let projects: [PointProject]

    init(companies: [PointDeviceCompany], projects: [PointProject]) {
        self.companies = companies
        self.projects = projects
    }

    private enum CodingKeys: String, CodingKey {
        case companies, projects, data
    }

    private struct NestedLists: Decodable {
        let companies: [PointDeviceCompany]?
        let projects: [PointProject]?
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Сервер отдаёт `{ ok, data: { companies, projects } }`. Сначала `data`, иначе корневой decode с пустыми ключами дал бы пустые списки без ошибки.
        if c.contains(.data) {
            let nested = try c.decode(NestedLists.self, forKey: .data)
            companies = nested.companies ?? []
            projects = nested.projects ?? []
            return
        }
        companies = (try c.decodeIfPresent([PointDeviceCompany].self, forKey: .companies)) ?? []
        projects = (try c.decodeIfPresent([PointProject].self, forKey: .projects)) ?? []
    }
}

struct PointDeviceCompany: Decodable, Identifiable {
    let id: String
    let name: String
    let code: String?
}

struct PointProject: Decodable, Identifiable {
    let id: String
    let name: String
    let mode: String?
    let isActive: Bool
    let token: String?
    let createdAt: String?
    let lastSeenAt: String?
    let featureFlags: PointFeatureFlags?
    let companyAssignments: [PointCompanyAssignment]

    enum CodingKeys: String, CodingKey {
        case id, name
        case mode = "point_mode"
        case token = "project_token"
        case isActive = "is_active"
        case createdAt = "created_at"
        case lastSeenAt = "last_seen_at"
        case featureFlags = "feature_flags"
        case companyAssignments = "companies"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        mode = try c.decodeIfPresent(String.self, forKey: .mode)
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
        token = try c.decodeIfPresent(String.self, forKey: .token)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        lastSeenAt = try c.decodeIfPresent(String.self, forKey: .lastSeenAt)
        featureFlags = try c.decodeIfPresent(PointFeatureFlags.self, forKey: .featureFlags)
        companyAssignments = (try c.decodeIfPresent([PointCompanyAssignment].self, forKey: .companyAssignments)) ?? []
    }
}

struct PointFeatureFlags: Decodable {
    let shiftReport: Bool
    let incomeReport: Bool
    let debtReport: Bool
    let kaspiDailySplit: Bool
    let startCashPrompt: Bool
    let arenaEnabled: Bool
    let arenaShiftAutoTotals: Bool

    enum CodingKeys: String, CodingKey {
        case shiftReport = "shift_report"
        case incomeReport = "income_report"
        case debtReport = "debt_report"
        case kaspiDailySplit = "kaspi_daily_split"
        case startCashPrompt = "start_cash_prompt"
        case arenaEnabled = "arena_enabled"
        case arenaShiftAutoTotals = "arena_shift_auto_totals"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        shiftReport = try c.decodeIfPresent(Bool.self, forKey: .shiftReport) ?? true
        incomeReport = try c.decodeIfPresent(Bool.self, forKey: .incomeReport) ?? true
        debtReport = try c.decodeIfPresent(Bool.self, forKey: .debtReport) ?? false
        kaspiDailySplit = try c.decodeIfPresent(Bool.self, forKey: .kaspiDailySplit) ?? false
        startCashPrompt = try c.decodeIfPresent(Bool.self, forKey: .startCashPrompt) ?? false
        arenaEnabled = try c.decodeIfPresent(Bool.self, forKey: .arenaEnabled) ?? false
        arenaShiftAutoTotals = try c.decodeIfPresent(Bool.self, forKey: .arenaShiftAutoTotals) ?? false
    }
}

struct PointCompanyAssignment: Decodable {
    let companyId: String
    let modeOverride: String?
    let featureFlags: PointFeatureFlags?

    enum CodingKeys: String, CodingKey {
        case companyId = "id"
        case modeOverride = "point_mode"
        case featureFlags = "feature_flags"
    }
}

// MARK: - Mutation payloads

struct PointDeviceActionBody<P: Encodable>: Encodable {
    let action: String
    let payload: P
}

struct PointProjectCreatePayload: Encodable {
    let name: String
    let companyAssignments: [PointCompanyAssignmentPayload]
    let featureFlags: PointFeatureFlagsPayload

    enum CodingKeys: String, CodingKey {
        case name
        case companyAssignments = "companyAssignments"
        case featureFlags = "featureFlags"
    }
}

struct PointProjectUpdatePayload: Encodable {
    let projectId: String
    let name: String
    let companyAssignments: [PointCompanyAssignmentPayload]
    let featureFlags: PointFeatureFlagsPayload
}

struct PointCompanyAssignmentPayload: Encodable {
    let companyId: String

    enum CodingKeys: String, CodingKey {
        case companyId = "company_id"
    }
}

struct PointFeatureFlagsPayload: Encodable {
    var shiftReport: Bool = true
    var incomeReport: Bool = true
    var debtReport: Bool = false
    var kaspiDailySplit: Bool = false
    var startCashPrompt: Bool = false
    var arenaEnabled: Bool = false

    enum CodingKeys: String, CodingKey {
        case shiftReport = "shift_report"
        case incomeReport = "income_report"
        case debtReport = "debt_report"
        case kaspiDailySplit = "kaspi_daily_split"
        case startCashPrompt = "start_cash_prompt"
        case arenaEnabled = "arena_enabled"
    }
}

struct PointToggleActivePayload: Encodable {
    let projectId: String
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case projectId
        case isActive = "isActive"
    }
}

struct PointRotateTokenPayload: Encodable {
    let projectId: String
}

struct PointDeleteProjectPayload: Encodable {
    let projectId: String
}
