import Foundation

enum OnboardingStep: Int, CaseIterable {
    case basicInfo = 0
    case publicLink = 1
    case legalDetails = 2
    case fulfillment = 3
    case openingHours = 4
    case firstMenu = 5
    case finish = 6

    var title: String {
        switch self {
        case .basicInfo:
            return "Podstawowe informacje"
        case .publicLink:
            return "Link publiczny"
        case .legalDetails:
            return "Dane prawne"
        case .fulfillment:
            return "Realizacja i płatność"
        case .openingHours:
            return "Godziny otwarcia"
        case .firstMenu:
            return "Pierwsza kategoria i pozycja"
        case .finish:
            return "Wszystko gotowe"
        }
    }

    var subtitle: String {
        switch self {
        case .basicInfo:
            return "Dodaj dane widoczne na stronie lokalu"
        case .publicLink:
            return "Ustaw adres, który udostępnisz klientom"
        case .legalDetails:
            return "Te dane będą wyświetlane w regulaminie i polityce prywatności"
        case .fulfillment:
            return "Określ odbiór, dostawę i metody płatności"
        case .openingHours:
            return "Ustaw godziny przyjmowania zamówień"
        case .firstMenu:
            return "Dodaj pierwszą kategorię i pierwszą pozycję"
        case .finish:
            return "Sprawdź wszystko przed utworzeniem panelu"
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
    var logoImageData: Data?

    var username = ""

    var legalBusinessName = ""
    var businessDisplayName = ""
    var nip = ""
    var addressLine1 = ""
    var addressLine2 = ""
    var postalCode = ""
    var city = ""
    var country = "Poland"
    var contactEmail = ""
    var contactPhone = ""
    var complaintEmail = ""
    var complaintPhone = ""

    var pickupAvailable = true
    var deliveryAvailable = false
    var deliveryArea = ""
    var cashPaymentAvailable = true
    var cardPaymentAvailable = false
    var blikPaymentAvailable = false

    var categoryName = ""
    var firstItemName = ""
    var firstItemDescription = ""
    var firstItemPrice = ""
    var firstItemImageData: Data?

    var days: [DayHoursDraft] = DayHoursDraft.defaultWeek
}

extension DayHoursDraft {
    static var defaultWeek: [DayHoursDraft] {
        [
            .init(weekday: 1, title: "Poniedziałek", isClosed: false, openDate: Self.makeDate(hour: 10, minute: 0), closeDate: Self.makeDate(hour: 22, minute: 0)),
            .init(weekday: 2, title: "Wtorek", isClosed: false, openDate: Self.makeDate(hour: 10, minute: 0), closeDate: Self.makeDate(hour: 22, minute: 0)),
            .init(weekday: 3, title: "Środa", isClosed: false, openDate: Self.makeDate(hour: 10, minute: 0), closeDate: Self.makeDate(hour: 22, minute: 0)),
            .init(weekday: 4, title: "Czwartek", isClosed: false, openDate: Self.makeDate(hour: 10, minute: 0), closeDate: Self.makeDate(hour: 22, minute: 0)),
            .init(weekday: 5, title: "Piątek", isClosed: false, openDate: Self.makeDate(hour: 10, minute: 0), closeDate: Self.makeDate(hour: 22, minute: 0)),
            .init(weekday: 6, title: "Sobota", isClosed: false, openDate: Self.makeDate(hour: 11, minute: 0), closeDate: Self.makeDate(hour: 23, minute: 0)),
            .init(weekday: 7, title: "Niedziela", isClosed: false, openDate: Self.makeDate(hour: 11, minute: 0), closeDate: Self.makeDate(hour: 21, minute: 0))
        ]
    }

    private static func makeDate(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? .now
    }
}
