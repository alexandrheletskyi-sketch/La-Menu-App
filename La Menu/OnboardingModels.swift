import Foundation

enum OnboardingStep: Int, CaseIterable {
    case basicInfo = 0
    case publicLink = 1
    case brandColor = 2
    case legalDetails = 3
    case fulfillment = 4
    case openingHours = 5
    case orderSettings = 6
    case firstMenu = 7
    case finish = 8

    var title: String {
        switch self {
        case .basicInfo:
            return "Podstawowe informacje"
        case .publicLink:
            return "Link publiczny"
        case .brandColor:
            return "Kolor firmowy"
        case .legalDetails:
            return "Dane prawne"
        case .fulfillment:
            return "Realizacja i płatność"
        case .openingHours:
            return "Godziny otwarcia"
        case .orderSettings:
            return "Przyjmowanie zamówień"
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
        case .brandColor:
            return "Wybierz kolor marki widoczny w aplikacji i na stronie"
        case .legalDetails:
            return "Te dane będą wyświetlane w regulaminie i polityce prywatności"
        case .fulfillment:
            return "Określ odbiór, dostawę i metody płatności"
        case .openingHours:
            return "Ustaw godziny przyjmowania zamówień"
        case .orderSettings:
            return "Ustaw status przyjmowania zamówień, odstęp między slotami i SMS"
        case .firstMenu:
            return "Dodaj pierwszą kategorię i pierwszą pozycję"
        case .finish:
            return "Sprawdź wszystko przed utworzeniem panelu"
        }
    }
}

struct DayHoursDraft: Identifiable, Equatable, Sendable {
    var id: Int { weekday }
    let weekday: Int
    let title: String
    var isClosed: Bool
    var openDate: Date
    var closeDate: Date
}

struct OnboardingDraft: Equatable, Sendable {
    var businessName = ""
    var description = ""
    var address = ""
    var phone = ""
    var logoImageData: Data? = nil

    var username = ""

    var accentColorHex = "#FFAA00"

    var legalBusinessName = ""
    var businessDisplayName = ""
    var nip = ""
    var addressLine1 = ""
    var addressLine2 = ""
    var postalCode = ""
    var city = ""
    var country = "Polska"
    var contactEmail = ""
    var contactPhone = ""
    var complaintEmail = ""
    var complaintPhone = ""

    var pickupAvailable = true
    var deliveryAvailable = false
    var deliveryArea = ""
    var deliveryPricePerKm = ""
    var cashPaymentAvailable = true
    var cardPaymentAvailable = false
    var blikPaymentAvailable = false

    var isAcceptingOrders = true
    var slotIntervalMinutes = 15
    var smsConfirmationEnabled = true

    var categoryName = ""
    var firstItemName = ""
    var firstItemDescription = ""
    var firstItemPrice = ""
    var firstItemImageData: Data? = nil

    var days: [DayHoursDraft] = DayHoursDraft.defaultWeek
}

extension DayHoursDraft {
    static var defaultWeek: [DayHoursDraft] {
        [
            .init(
                weekday: 1,
                title: "Poniedziałek",
                isClosed: false,
                openDate: Self.makeDate(hour: 10, minute: 0),
                closeDate: Self.makeDate(hour: 22, minute: 0)
            ),
            .init(
                weekday: 2,
                title: "Wtorek",
                isClosed: false,
                openDate: Self.makeDate(hour: 10, minute: 0),
                closeDate: Self.makeDate(hour: 22, minute: 0)
            ),
            .init(
                weekday: 3,
                title: "Środa",
                isClosed: false,
                openDate: Self.makeDate(hour: 10, minute: 0),
                closeDate: Self.makeDate(hour: 22, minute: 0)
            ),
            .init(
                weekday: 4,
                title: "Czwartek",
                isClosed: false,
                openDate: Self.makeDate(hour: 10, minute: 0),
                closeDate: Self.makeDate(hour: 22, minute: 0)
            ),
            .init(
                weekday: 5,
                title: "Piątek",
                isClosed: false,
                openDate: Self.makeDate(hour: 10, minute: 0),
                closeDate: Self.makeDate(hour: 22, minute: 0)
            ),
            .init(
                weekday: 6,
                title: "Sobota",
                isClosed: false,
                openDate: Self.makeDate(hour: 11, minute: 0),
                closeDate: Self.makeDate(hour: 23, minute: 0)
            ),
            .init(
                weekday: 7,
                title: "Niedziela",
                isClosed: false,
                openDate: Self.makeDate(hour: 11, minute: 0),
                closeDate: Self.makeDate(hour: 21, minute: 0)
            )
        ]
    }

    private static func makeDate(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? .now
    }
}
