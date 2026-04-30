import Foundation

enum SubscriptionPlan: String, Codable, CaseIterable {
    case free
    case plus
    case business
    case premium

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

    var priceText: String {
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
            return "Dla startu i małych lokali"
        case .plus:
            return "Nielimitowane menu i pakiet 200 SMS"
        case .business:
            return "Dla lokali z większą liczbą zamówień"
        case .premium:
            return "Najwyższy pakiet dla najbardziej aktywnych lokali"
        }
    }

    static func from(_ rawValue: String?) -> SubscriptionPlan {
        guard let rawValue,
              let plan = SubscriptionPlan(rawValue: rawValue.lowercased()) else {
            return .free
        }
        return plan
    }
}
