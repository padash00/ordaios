import Foundation

struct ClientRegistrationOptionsResponse: Decodable {
    let companies: [RegistrationCompany]
    let points: [RegistrationPoint]

    private enum CodingKeys: String, CodingKey {
        case companies
        case points
        case data
    }

    private struct NestedData: Decodable {
        let companies: [RegistrationCompany]
        let points: [RegistrationPoint]
    }

    init(companies: [RegistrationCompany], points: [RegistrationPoint]) {
        self.companies = companies
        self.points = points
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let companies = try container.decodeIfPresent([RegistrationCompany].self, forKey: .companies),
           let points = try container.decodeIfPresent([RegistrationPoint].self, forKey: .points) {
            self.companies = companies
            self.points = points
            return
        }
        if let nested = try container.decodeIfPresent(NestedData.self, forKey: .data) {
            self.companies = nested.companies
            self.points = nested.points
            return
        }
        self.companies = []
        self.points = []
    }
}

struct RegistrationCompany: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let code: String
}

struct RegistrationPoint: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let companyIds: [String]
}

struct ClientRegisterRequest: Encodable {
    let phone: String
    let name: String?
    /// Код компании из `GET /api/public/client/options` — на проде обычно обязателен, если нет `DEFAULT_CLIENT_COMPANY_CODE` и несколько компаний.
    let companyCode: String?
    /// UUID `point_projects` из того же ответа — рекомендуется передавать всегда.
    let pointProjectId: String?

    enum CodingKeys: String, CodingKey {
        case phone, name, companyCode, pointProjectId
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(phone, forKey: .phone)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(companyCode, forKey: .companyCode)
        try c.encodeIfPresent(pointProjectId, forKey: .pointProjectId)
    }
}
