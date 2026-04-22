import Foundation

enum SubscriptionPlan: String, Codable, CaseIterable {
    case free
    case business
    case plus

    var title: String {
        switch self {
        case .free: return "Free"
        case .business: return "Business"
        case .plus: return "Plus"
        }
    }

    var menuItemLimit: Int? {
        switch self {
        case .free:
            return 20
        case .business, .plus:
            return nil
        }
    }

    var smsCreditsIncluded: Int {
        switch self {
        case .free:
            return 20
        case .business:
            return 200
        case .plus:
            return 700
        }
    }

    var menuLimitText: String {
        switch self {
        case .free:
            return "Do 20 pozycji w menu"
        case .business, .plus:
            return "Nielimitowane menu"
        }
    }

    var smsCreditsText: String {
        "\(smsCreditsIncluded) SMS kredytów"
    }

    var shortDescription: String {
        switch self {
        case .free:
            return "Dla startu i małych lokali"
        case .business:
            return "Dla lokali, które chcą rosnąć"
        case .plus:
            return "Najwięcej SMS i pełna swoboda"
        }
    }

    static func from(_ rawValue: String?) -> SubscriptionPlan {
        guard let rawValue, let plan = SubscriptionPlan(rawValue: rawValue.lowercased()) else {
            return .free
        }
        return plan
    }
}
