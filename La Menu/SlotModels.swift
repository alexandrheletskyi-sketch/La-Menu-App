import Foundation

enum SlotFulfillmentType: String, Codable, CaseIterable, Identifiable, Sendable {
    case pickup
    case delivery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pickup:
            return "Odbiór"
        case .delivery:
            return "Dostawa"
        }
    }
}

struct VenueSlotSettings: Codable, Equatable, Sendable {
    let profileId: UUID
    var slotDurationMinutes: Int
    var defaultCapacity: Int
    var daysAhead: Int
    var leadTimeMinutes: Int
    var allowAsap: Bool
    var earliestPickupTimeText: String?

    enum CodingKeys: String, CodingKey {
        case profileId = "profile_id"
        case slotDurationMinutes = "slot_duration"
        case defaultCapacity = "default_capacity"
        case daysAhead = "days_ahead"
        case leadTimeMinutes = "lead_time_min"
        case allowAsap = "allow_asap"
        case earliestPickupTimeText = "earliest_pickup_time_text"
    }

    static func placeholder(profileId: UUID) -> VenueSlotSettings {
        .init(
            profileId: profileId,
            slotDurationMinutes: 15,
            defaultCapacity: 3,
            daysAhead: 7,
            leadTimeMinutes: 0,
            allowAsap: true,
            earliestPickupTimeText: nil
        )
    }
}

struct AvailableSlot: Codable, Identifiable, Hashable, Sendable {
    var id: String { slotStart }

    let slotStart: String
    let slotEnd: String
    let slotLabel: String
    let capacity: Int
    let taken: Int
    let remaining: Int
    let isAvailable: Bool
    let isBlocked: Bool
    let hasCapacityOverride: Bool
    let status: String

    enum CodingKeys: String, CodingKey {
        case slotStart = "slot_start"
        case slotEnd = "slot_end"
        case slotLabel = "slot_label"
        case capacity
        case taken
        case remaining
        case isAvailable = "is_available"
        case isBlocked = "is_blocked"
        case hasCapacityOverride = "has_capacity_override"
        case status
    }

    var slotStartRaw: String {
        Self.extractHHmm(from: slotStart)
    }

    var subtitle: String {
        "Zajęte \(taken) z \(capacity)"
    }

    var statusTitle: String {
        switch status {
        case "available":
            return "Dostępny"
        case "blocked":
            return "Zablokowany"
        case "full":
            return "Pełny"
        case "too_late":
            return "Za późно"
        default:
            return "Nieznany"
        }
    }

    private static func extractHHmm(from value: String) -> String {
        let raw = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if raw.count >= 16, raw.contains("T") {
            let start = raw.index(raw.startIndex, offsetBy: 11)
            let end = raw.index(start, offsetBy: 5)
            return String(raw[start..<end])
        }

        if raw.count >= 5, raw.contains(":") {
            return String(raw.prefix(5))
        }

        return raw
    }
}

struct AdminDaySlot: Codable, Identifiable, Hashable, Sendable {
    var id: String { slotStart }

    let slotStart: String
    let slotEnd: String
    let slotLabel: String
    let capacity: Int
    let taken: Int
    let remaining: Int
    let isAvailable: Bool
    let isBlocked: Bool
    let hasCapacityOverride: Bool
    let status: String

    enum CodingKeys: String, CodingKey {
        case slotStart = "slot_start"
        case slotEnd = "slot_end"
        case slotLabel = "slot_label"
        case capacity
        case taken
        case remaining
        case isAvailable = "is_available"
        case isBlocked = "is_blocked"
        case hasCapacityOverride = "has_capacity_override"
        case status
    }

    var slotStartRaw: String {
        Self.extractHHmm(from: slotStart)
    }

    var subtitle: String {
        "Zajęte \(taken) z \(capacity)"
    }

    var capacityOverrideValue: Int? {
        nil
    }

    var statusTitle: String {
        switch status {
        case "available":
            return "Dostępny"
        case "blocked":
            return "Zablokowany"
        case "full":
            return "Pełny"
        case "too_late":
            return "Za późно"
        default:
            return "Nieznany"
        }
    }

    private static func extractHHmm(from value: String) -> String {
        let raw = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if raw.count >= 16, raw.contains("T") {
            let start = raw.index(raw.startIndex, offsetBy: 11)
            let end = raw.index(start, offsetBy: 5)
            return String(raw[start..<end])
        }

        if raw.count >= 5, raw.contains(":") {
            return String(raw.prefix(5))
        }

        return raw
    }
}

struct SlotOverride: Codable, Identifiable, Sendable {
    let id: UUID?
    let profileId: UUID
    let fulfillmentType: SlotFulfillmentType
    let slotStart: String
    let slotEnd: String?
    let isBlocked: Bool
    let capacityOverride: Int?
    let note: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case fulfillmentType = "fulfillment_type"
        case slotStart = "slot_start"
        case slotEnd = "slot_end"
        case isBlocked = "is_blocked"
        case capacityOverride = "capacity_override"
        case note
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SlotDateOverride: Codable, Identifiable, Sendable {
    let id: UUID?
    let profileId: UUID
    let overrideDate: String
    let fulfillmentType: SlotFulfillmentType
    let isClosed: Bool
    let openTime: String?
    let closeTime: String?
    let capacityOverride: Int?
    let note: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case overrideDate = "override_date"
        case fulfillmentType = "fulfillment_type"
        case isClosed = "is_closed"
        case openTime = "open_time"
        case closeTime = "close_time"
        case capacityOverride = "capacity_override"
        case note
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SlotTimeOverride: Codable, Identifiable, Sendable {
    let id: UUID?
    let profileId: UUID
    let overrideDate: String
    let fulfillmentType: SlotFulfillmentType
    let slotTime: String
    let isBlocked: Bool
    let capacityOverride: Int?
    let note: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case overrideDate = "override_date"
        case fulfillmentType = "fulfillment_type"
        case slotTime = "slot_time"
        case isBlocked = "is_blocked"
        case capacityOverride = "capacity_override"
        case note
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SlotDateOverrideDraft: Sendable {
    var isClosed: Bool = false
    var openDate: Date = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: .now) ?? .now
    var closeDate: Date = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: .now) ?? .now
    var capacityOverride: String = ""
    var note: String = ""

    static var empty: SlotDateOverrideDraft { .init() }
}

extension ISO8601DateFormatter {
    static let supabase: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        return formatter
    }()
}

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let hm24: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let polishDayTitle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.dateFormat = "EEEE, d MMM"
        return formatter
    }()
}
