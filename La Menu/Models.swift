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
    var continueAfterHours: Bool
    var onboardingCompleted: Bool

    var pickupEnabled: Bool
    var deliveryEnabled: Bool
    var accentColor: String?
    var slotIntervalMinutes: Int?
    var deliveryPricePerKm: Double?
    var smsConfirmationEnabled: Bool

    var subscriptionPlanRaw: String?
    var smsCredits: Int?
    var smsUsedThisMonth: Int?
    var smsUsedCurrentMonth: Int?
    var smsUsageMonth: String?

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
        case continueAfterHours = "continue_after_hours"
        case onboardingCompleted = "onboarding_completed"
        case pickupEnabled = "pickup_enabled"
        case deliveryEnabled = "delivery_enabled"
        case accentColor = "accent_color"
        case slotIntervalMinutes = "slot_interval_minutes"
        case deliveryPricePerKm = "delivery_price_per_km"
        case smsConfirmationEnabled = "sms_confirmation_enabled"
        case subscriptionPlanRaw = "subscription_plan"
        case smsCredits = "sms_credits"
        case smsUsedThisMonth = "sms_used_this_month"
        case smsUsedCurrentMonth = "sms_used_current_month"
        case smsUsageMonth = "sms_usage_month"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var subscriptionPlan: SubscriptionPlan {
        SubscriptionPlan.from(subscriptionPlanRaw)
    }

    var subscriptionPlanTitle: String {
        subscriptionPlan.title
    }

    var menuItemsLimit: Int? {
        subscriptionPlan.menuItemLimit
    }

    var hasUnlimitedMenuItems: Bool {
        subscriptionPlan.menuItemLimit == nil
    }

    var includedSmsCredits: Int {
        subscriptionPlan.smsCreditsIncluded
    }

    var currentSmsCredits: Int {
        smsCredits ?? subscriptionPlan.smsCreditsIncluded
    }

    var subscriptionDescription: String {
        subscriptionPlan.shortDescription
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

struct SMSUsageOverview: Codable, Hashable {
    var smsLimit: Int
    var smsRemaining: Int
    var smsUsedThisPeriod: Int

    enum CodingKeys: String, CodingKey {
        case smsLimit = "sms_limit"
        case smsRemaining = "sms_remaining"
        case smsUsedThisPeriod = "sms_used_this_period"
    }
}
