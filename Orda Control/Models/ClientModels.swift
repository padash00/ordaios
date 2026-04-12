import Foundation

struct ClientProfileResponse: Decodable {
    let ok: Bool
    let persona: String?
    let customers: [ActiveCustomer]
    let activeCustomer: ActiveCustomer?

    private enum CodingKeys: String, CodingKey {
        case ok, persona, customers, activeCustomer
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? true
        persona = try c.decodeIfPresent(String.self, forKey: .persona)
        customers = try c.decodeIfPresent([ActiveCustomer].self, forKey: .customers) ?? []
        activeCustomer = try c.decodeIfPresent(ActiveCustomer.self, forKey: .activeCustomer)
    }
}

struct ActiveCustomer: Decodable, Equatable, Identifiable {
    let id: String
    let companyId: String?
    let name: String
    let phone: String?
    let loyaltyPoints: Int
    let visitsCount: Int
    let totalSpent: Double?

    init(
        id: String,
        companyId: String? = nil,
        name: String,
        phone: String? = nil,
        loyaltyPoints: Int,
        visitsCount: Int,
        totalSpent: Double? = nil
    ) {
        self.id = id
        self.companyId = companyId
        self.name = name
        self.phone = phone
        self.loyaltyPoints = loyaltyPoints
        self.visitsCount = visitsCount
        self.totalSpent = totalSpent
    }
}

struct BookingsResponse: Decodable {
    let ok: Bool
    let bookings: [Booking]
    let hasMore: Bool
    let nextOffset: Int?

    private enum CodingKeys: String, CodingKey {
        case ok
        case bookings
        case data
        case hasMore
        case nextOffset
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ok = try container.decodeIfPresent(Bool.self, forKey: .ok) ?? true
        bookings = try container.decodeIfPresent([Booking].self, forKey: .bookings)
            ?? container.decodeIfPresent([Booking].self, forKey: .data)
            ?? []
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
        nextOffset = try container.decodeIfPresent(Int.self, forKey: .nextOffset)
    }
}

struct Booking: Decodable, Equatable, Identifiable {
    let id: String
    let companyId: String?
    let customerId: String?
    let startsAt: Date
    let endsAt: Date
    let status: String
    let notes: String?
    let createdAt: Date
}

struct CreateBookingRequest: Encodable {
    let startsAt: String
    let endsAt: String?
    let notes: String?
    let companyId: String?

    init(startsAt: String, endsAt: String? = nil, notes: String?, companyId: String?) {
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.notes = notes
        self.companyId = companyId
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(startsAt, forKey: .startsAt)
        try c.encodeIfPresent(endsAt, forKey: .endsAt)
        try c.encodeIfPresent(notes, forKey: .notes)
        try c.encodeIfPresent(companyId, forKey: .companyId)
    }

    private enum CodingKeys: String, CodingKey {
        case startsAt, endsAt, notes, companyId
    }
}

struct CancelBookingRequest: Encodable {
    let action: String
    let bookingId: String
}

struct PointsResponse: Decodable {
    let ok: Bool
    let summary: PointsSummary
    let history: [PointsHistoryItem]
    let hasMore: Bool
    let nextOffset: Int?

    private enum CodingKeys: String, CodingKey {
        case ok
        case summary
        case history
        case hasMore
        case nextOffset
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ok = try container.decodeIfPresent(Bool.self, forKey: .ok) ?? true
        summary = try container.decode(PointsSummary.self, forKey: .summary)
        history = try container.decodeIfPresent([PointsHistoryItem].self, forKey: .history) ?? []
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
        nextOffset = try container.decodeIfPresent(Int.self, forKey: .nextOffset)
    }
}

struct RedeemPointsRequest: Encodable {
    let action: String
    let rewardId: String
    let rewardTitle: String
    let pointsCost: Int
    let minTierKey: String
}

struct RedeemPointsResponse: Decodable {
    let ok: Bool
    let summary: PointsSummary
    let redemption: PointsHistoryItem?

    private enum CodingKeys: String, CodingKey {
        case ok, summary, redemption
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? true
        summary = try c.decode(PointsSummary.self, forKey: .summary)
        redemption = try c.decodeIfPresent(PointsHistoryItem.self, forKey: .redemption)
    }
}

struct PointsSummary: Decodable, Equatable {
    let customerId: String?
    let points: Int
    let totalSpent: Double
    let visits: Int

    private enum CodingKeys: String, CodingKey {
        case customerId = "customer_id"
        case points
        case totalSpent
        case visits
    }

    nonisolated init(customerId: String?, points: Int, totalSpent: Double, visits: Int) {
        self.customerId = customerId
        self.points = points
        self.totalSpent = totalSpent
        self.visits = visits
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        customerId = try c.decodeIfPresent(String.self, forKey: .customerId)
        points = (try c.decodeIfPresent(Int.self, forKey: .points)) ?? 0
        if let d = try c.decodeIfPresent(Double.self, forKey: .totalSpent) {
            totalSpent = d
        } else if let s = try c.decodeIfPresent(String.self, forKey: .totalSpent), let d = Double(s) {
            totalSpent = d
        } else {
            totalSpent = 0
        }
        visits = (try c.decodeIfPresent(Int.self, forKey: .visits)) ?? 0
    }
}

struct PointsHistoryItem: Decodable, Equatable, Identifiable {
    let id: String
    let saleDate: String?
    let loyaltyPointsEarned: Int?
    let loyaltyPointsSpent: Int?
    let totalAmount: Double?
    let customerId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case saleDate = "sale_date"
        case loyaltyPointsEarned = "loyalty_points_earned"
        case loyaltyPointsSpent = "loyalty_points_spent"
        case totalAmount = "total_amount"
        case customerId = "customer_id"
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        saleDate = try c.decodeIfPresent(String.self, forKey: .saleDate)
        loyaltyPointsEarned = try c.decodeIfPresent(Int.self, forKey: .loyaltyPointsEarned)
        loyaltyPointsSpent = try c.decodeIfPresent(Int.self, forKey: .loyaltyPointsSpent)
        totalAmount = try c.decodeIfPresent(Double.self, forKey: .totalAmount)
        customerId = try c.decodeIfPresent(String.self, forKey: .customerId)
    }

    var netDelta: Int {
        (loyaltyPointsEarned ?? 0) - (loyaltyPointsSpent ?? 0)
    }
}

struct SupportResponse: Decodable {
    let ok: Bool
    let requests: [SupportRequestItem]
    let hasMore: Bool
    let nextOffset: Int?

    private enum CodingKeys: String, CodingKey {
        case ok
        case requests
        case data
        case hasMore
        case nextOffset
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ok = try container.decodeIfPresent(Bool.self, forKey: .ok) ?? true
        requests = try container.decodeIfPresent([SupportRequestItem].self, forKey: .requests)
            ?? container.decodeIfPresent([SupportRequestItem].self, forKey: .data)
            ?? []
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
        nextOffset = try container.decodeIfPresent(Int.self, forKey: .nextOffset)
    }
}

struct SupportRequestItem: Decodable, Equatable, Identifiable {
    let id: String
    let status: String
    let priority: String?
    let message: String
    let createdAt: Date
    let companyId: String?
    let subject: String?
}

struct CreateSupportRequest: Encodable {
    let message: String
    let companyId: String?

    init(message: String, companyId: String? = nil) {
        self.message = message
        self.companyId = companyId
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(message, forKey: .message)
        try c.encodeIfPresent(companyId, forKey: .companyId)
    }

    private enum CodingKeys: String, CodingKey {
        case message, companyId
    }
}

struct APIStatusResponse: Decodable {
    let ok: Bool

    private enum CodingKeys: String, CodingKey {
        case ok
        case data
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let ok = try container.decodeIfPresent(Bool.self, forKey: .ok) {
            self.ok = ok
            return
        }
        let hasError = (try container.decodeIfPresent(String.self, forKey: .error)) != nil
        self.ok = !hasError
    }
}
