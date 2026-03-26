import Foundation

struct Profile: Codable, Identifiable, Hashable {
    var id: UUID
    var ownerUserId: UUID?
    var businessName: String
    var username: String
    var description: String?
    var phone: String?
    var email: String?
    var address: String?
    var logoURL: String?
    var coverURL: String?
    var isActive: Bool
    var isAcceptingOrders: Bool
    var onboardingCompleted: Bool
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserId = "owner_user_id"
        case businessName = "business_name"
        case username
        case description
        case phone
        case email
        case address
        case logoURL = "logo_url"
        case coverURL = "cover_url"
        case isActive = "is_active"
        case isAcceptingOrders = "is_accepting_orders"
        case onboardingCompleted = "onboarding_completed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct BusinessHour: Codable, Identifiable, Hashable {
    var id: UUID
    var profileId: UUID
    var weekday: Int
    var isClosed: Bool
    var openTime: String?
    var closeTime: String?
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case weekday
        case isClosed = "is_closed"
        case openTime = "open_time"
        case closeTime = "close_time"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct Order: Codable, Identifiable, Hashable {
    var id: UUID
    var profileId: UUID
    var customerName: String?
    var customerPhone: String?
    var fulfillmentType: String
    var pickupTime: String?
    var totalAmount: Double
    var status: String
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case customerName = "customer_name"
        case customerPhone = "customer_phone"
        case fulfillmentType = "fulfillment_type"
        case pickupTime = "pickup_time"
        case totalAmount = "total_amount"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct OrderItem: Codable, Identifiable, Hashable {
    var id: UUID
    var orderId: UUID
    var menuItemId: UUID?
    var name: String
    var quantity: Int
    var unitPrice: Double
    var lineTotal: Double
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case orderId = "order_id"
        case menuItemId = "menu_item_id"
        case name
        case quantity
        case unitPrice = "unit_price"
        case lineTotal = "line_total"
        case createdAt = "created_at"
    }
}
