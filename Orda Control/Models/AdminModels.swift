import Foundation

struct AdminBookingsResponse: Decodable {
    let ok: Bool
    let bookings: [AdminBooking]
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
        bookings = try container.decodeIfPresent([AdminBooking].self, forKey: .bookings)
            ?? container.decodeIfPresent([AdminBooking].self, forKey: .data)
            ?? []
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
        nextOffset = try container.decodeIfPresent(Int.self, forKey: .nextOffset)
    }
}

struct AdminBooking: Decodable, Identifiable, Equatable {
    let id: String
    let customerName: String?
    let startsAt: Date
    let endsAt: Date
    let status: String
    let notes: String?
    let createdAt: Date
}

struct AdminBookingStatusRequest: Encodable {
    let action: String
    let bookingId: String
    let status: String
}

struct AdminSupportResponse: Decodable {
    let ok: Bool
    let requests: [AdminSupportTicket]
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
        requests = try container.decodeIfPresent([AdminSupportTicket].self, forKey: .requests)
            ?? container.decodeIfPresent([AdminSupportTicket].self, forKey: .data)
            ?? []
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
        nextOffset = try container.decodeIfPresent(Int.self, forKey: .nextOffset)
    }
}

struct AdminSupportTicket: Decodable, Identifiable, Equatable {
    let id: String
    let customerName: String?
    let status: String
    let priority: String?
    let message: String
    let createdAt: Date
}

struct AdminSupportStatusRequest: Encodable {
    let action: String
    let ticketId: String
    let status: String
    let priority: String?
    let assignedStaffId: String?

    enum CodingKeys: String, CodingKey {
        case action
        case ticketId
        case status
        case priority
        case assignedStaffId
    }
}
