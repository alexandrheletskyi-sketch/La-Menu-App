import Foundation

enum OnboardingStep: Int, CaseIterable {
    case basicInfo = 0
    case publicLink = 1
    case openingHours = 2
    case firstMenu = 3
    case finish = 4

    var title: String {
        switch self {
        case .basicInfo: return "Basic info"
        case .publicLink: return "Public link"
        case .openingHours: return "Opening hours"
        case .firstMenu: return "First menu"
        case .finish: return "Finish"
        }
    }

    var subtitle: String {
        switch self {
        case .basicInfo:
            return "Tell us about your place"
        case .publicLink:
            return "Choose your public menu link"
        case .openingHours:
            return "Set your working schedule"
        case .firstMenu:
            return "Create your first menu"
        case .finish:
            return "Review everything before launch"
        }
    }
}

struct DayHoursDraft: Identifiable {
    let id = UUID()
    let weekday: Int
    let title: String
    var isClosed: Bool
    var openDate: Date
    var closeDate: Date
}

struct OnboardingDraft {
    var businessName = ""
    var description = ""
    var address = ""
    var phone = ""

    var username = ""

    var menuTitle = "Main Menu"
    var categoryName = ""
    var firstItemName = ""
    var firstItemDescription = ""
    var firstItemPrice = ""

    var days: [DayHoursDraft] = DayHoursDraft.defaultWeek
}

extension DayHoursDraft {
    static var defaultWeek: [DayHoursDraft] {
        [
            .init(weekday: 1, title: "Monday", isClosed: false, openDate: Self.makeDate(hour: 10, minute: 0), closeDate: Self.makeDate(hour: 22, minute: 0)),
            .init(weekday: 2, title: "Tuesday", isClosed: false, openDate: Self.makeDate(hour: 10, minute: 0), closeDate: Self.makeDate(hour: 22, minute: 0)),
            .init(weekday: 3, title: "Wednesday", isClosed: false, openDate: Self.makeDate(hour: 10, minute: 0), closeDate: Self.makeDate(hour: 22, minute: 0)),
            .init(weekday: 4, title: "Thursday", isClosed: false, openDate: Self.makeDate(hour: 10, minute: 0), closeDate: Self.makeDate(hour: 22, minute: 0)),
            .init(weekday: 5, title: "Friday", isClosed: false, openDate: Self.makeDate(hour: 10, minute: 0), closeDate: Self.makeDate(hour: 22, minute: 0)),
            .init(weekday: 6, title: "Saturday", isClosed: false, openDate: Self.makeDate(hour: 11, minute: 0), closeDate: Self.makeDate(hour: 23, minute: 0)),
            .init(weekday: 7, title: "Sunday", isClosed: false, openDate: Self.makeDate(hour: 11, minute: 0), closeDate: Self.makeDate(hour: 21, minute: 0))
        ]
    }

    private static func makeDate(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? .now
    }
}
