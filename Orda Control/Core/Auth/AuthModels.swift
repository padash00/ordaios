import Foundation

struct Session: Codable, Equatable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?
    let userEmail: String
}

struct SupabaseAuthResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let tokenType: String?
    let user: SupabaseUser
}

struct SupabaseUser: Decodable {
    let email: String?
}

struct SessionRoleContext: Codable, Equatable {
    let isSuperAdmin: Bool
    let isStaff: Bool
    let isOperator: Bool
    let isCustomer: Bool
    let persona: String?
    let staffRole: String?
    let roleLabel: String?
    let defaultPath: String?
    let organizations: [RoleOrganization]?
    let activeOrganization: RoleOrganization?
    let activeSubscription: RoleSubscription?
    let rolePermissionOverrides: [RolePermissionOverride]?

    var appShell: AppShellType {
        AppShellResolver.resolve(from: self)
    }

    /// Picks a row id from `GET /api/admin/companies` for payloads that expect `company_id` (tasks, shifts, expenses). JWT organization ids are not guaranteed to match `companies.id`.
    func resolvedDatabaseCompanyId(companies: [AdminCompany]) -> String? {
        let ids = companies.map { $0.id.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !ids.isEmpty else { return nil }
        let allowed = Set(ids)
        if let org = activeOrganization {
            let raw = org.id.trimmingCharacters(in: .whitespacesAndNewlines)
            if !raw.isEmpty, allowed.contains(raw) { return raw }
        }
        if let list = organizations {
            for org in list {
                let id = org.id.trimmingCharacters(in: .whitespacesAndNewlines)
                if !id.isEmpty, allowed.contains(id) { return id }
            }
        }
        return ids.first
    }
}

struct RoleOrganization: Codable, Equatable, Identifiable {
    let id: String
    let name: String?
}

struct RoleSubscription: Codable, Equatable {
    let id: String?
    let status: String?
    let billingPeriod: String?
    let startsAt: String?
    let endsAt: String?
}

struct RolePermissionOverride: Codable, Equatable, Identifiable {
    let id: String
    let key: String?
    let value: String?
    let path: String?
    let enabled: Bool?

    init(
        id: String = UUID().uuidString,
        key: String?,
        value: String?,
        path: String? = nil,
        enabled: Bool? = nil
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.path = path
        self.enabled = enabled
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case key
        case value
        case path
        case enabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        key = try container.decodeIfPresent(String.self, forKey: .key)
        value = try container.decodeIfPresent(String.self, forKey: .value)
        path = try container.decodeIfPresent(String.self, forKey: .path)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(key, forKey: .key)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encodeIfPresent(path, forKey: .path)
        try container.encodeIfPresent(enabled, forKey: .enabled)
    }
}

enum AppShellType: String, Codable {
    case admin
    case staff
    case operatorRole
    case client
    case noAccess
}

enum OnboardingState: Equatable {
    case signIn
    case signUp
    case emailConfirmationPending(email: String)
    case registrationDetails
    case app
}
