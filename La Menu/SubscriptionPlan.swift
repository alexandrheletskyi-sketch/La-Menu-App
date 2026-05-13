import Foundation

enum SubscriptionPlan: String, Codable, CaseIterable, Hashable, Identifiable {
    case free
    case plus
    case business
    case premium

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .free:
            return "Free"
        case .plus:
            return "Plus"
        case .business:
            return "Business"
        case .premium:
            return "Premium"
        }
    }

    var productId: String? {
        switch self {
        case .free:
            return nil
        case .plus:
            return "lamenu.plus.monthly"
        case .business:
            return "lamenu.business.monthly"
        case .premium:
            return "lamenu.premium.monthly"
        }
    }

    static var paidProductIds: [String] {
        allCases.compactMap { $0.productId }
    }

    var menuItemLimit: Int? {
        switch self {
        case .free:
            return 20
        case .plus, .business, .premium:
            return nil
        }
    }

    var smsCreditsIncluded: Int {
        switch self {
        case .free:
            return 20
        case .plus:
            return 200
        case .business:
            return 500
        case .premium:
            return 1500
        }
    }

    var monthlyPrice: Decimal {
        switch self {
        case .free:
            return 0
        case .plus:
            return 29.99
        case .business:
            return 49.99
        case .premium:
            return 99.99
        }
    }

    var fallbackPriceText: String {
        switch self {
        case .free:
            return "$0"
        case .plus:
            return "$29.99"
        case .business:
            return "$49.99"
        case .premium:
            return "$99.99"
        }
    }

    var menuLimitText: String {
        switch self {
        case .free:
            return "Do 20 pozycji"
        case .plus, .business, .premium:
            return "Nielimitowane"
        }
    }

    var fullMenuLimitText: String {
        switch self {
        case .free:
            return "Do 20 pozycji w menu"
        case .plus, .business, .premium:
            return "Nielimitowane menu"
        }
    }

    var smsCreditsText: String {
        "\(smsCreditsIncluded) SMS"
    }

    var shortDescription: String {
        switch self {
        case .free:
            return "Na start dla małych lokali"
        case .plus:
            return "Więcej SMS i pełna swoboda menu"
        case .business:
            return "Dla rosnących lokali z większą liczbą zamówień"
        case .premium:
            return "Najwyższy pakiet dla najbardziej aktywnych lokali"
        }
    }

    var iconName: String {
        switch self {
        case .free:
            return "sparkles"
        case .plus:
            return "circle.grid.2x2.fill"
        case .business:
            return "briefcase.fill"
        case .premium:
            return "crown.fill"
        }
    }

    var sortOrder: Int {
        switch self {
        case .free:
            return 0
        case .plus:
            return 1
        case .business:
            return 2
        case .premium:
            return 3
        }
    }

    static func from(_ rawValue: String?) -> SubscriptionPlan {
        guard let rawValue,
              let plan = SubscriptionPlan(rawValue: rawValue.lowercased()) else {
            return .free
        }

        return plan
    }

    static func fromProductId(_ productId: String) -> SubscriptionPlan? {
        allCases.first { $0.productId == productId }
    }
}
