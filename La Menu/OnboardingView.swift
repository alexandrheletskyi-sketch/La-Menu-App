import SwiftUI
import PhotosUI
import UIKit

struct OnboardingView: View {
    @Environment(AuthViewModel.self) private var auth

    @State private var firstItemPhoto: PhotosPickerItem?
    @State private var firstItemImageData: Data?
    @State private var isSubmittingFinish = false

    private let pageBackground = Color.white
    private let mutedText = Color.black.opacity(0.58)
    private let secondaryText = Color.black.opacity(0.42)

    private var accentColor: Color {
        Color(lmHex: draft.accentColorHex)
    }

    private var accentSoft: Color {
        Color(lmHex: draft.accentColorHex).opacity(0.14)
    }

    private var step: OnboardingStep {
        get { auth.onboardingStep }
        nonmutating set { auth.onboardingStep = newValue }
    }

    private var draft: OnboardingDraft {
        get { auth.onboardingDraft }
        nonmutating set { auth.onboardingDraft = newValue }
    }

    private var usernameBinding: Binding<String> {
        Binding(
            get: { auth.onboardingDraft.username },
            set: { newValue in
                auth.updateUsernameDraft(newValue)
            }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                pageBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    topSection

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            currentStepView
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 132)
                    }
                    .background(Color.white)
                }

                bottomBar
            }
            .background(Color.white)
            .navigationBarBackButtonHidden(true)
        }
        .background(Color.white)
        .task(id: firstItemPhoto) {
            guard let firstItemPhoto else { return }
            firstItemImageData = try? await firstItemPhoto.loadTransferable(type: Data.self)
        }
        .onAppear {
            if firstItemImageData == nil {
                firstItemImageData = draft.firstItemImageData
            }
        }
    }

    private var topSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(stepEyebrow)
                    .font(.wix(12, wixWeight: .semiBold))
                    .foregroundStyle(.black.opacity(0.42))
                    .tracking(0.2)

                Text(step.title)
                    .font(.wix(32, wixWeight: .bold))
                    .foregroundStyle(.black)
                    .tracking(-0.7)

                Text(step.subtitle)
                    .font(.wix(15, wixWeight: .regular))
                    .foregroundStyle(mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(OnboardingStep.allCases, id: \.rawValue) { item in
                        Capsule()
                            .fill(item.rawValue <= step.rawValue ? accentColor : Color.black.opacity(0.08))
                            .frame(height: 7)
                    }
                }

                HStack {
                    Text("Krok \(step.rawValue + 1) z \(OnboardingStep.allCases.count)")
                        .font(.wix(13, wixWeight: .medium))
                        .foregroundStyle(secondaryText)

                    Spacer()

                    Text(progressLabel)
                        .font(.wix(13, wixWeight: .semiBold))
                        .foregroundStyle(.black.opacity(0.62))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(Color.white)
    }

    private var stepEyebrow: String {
        switch step {
        case .basicInfo:
            return "Konfiguracja lokalu"
        case .publicLink:
            return "Link publiczny"
        case .brandColor:
            return "Wygląd marki"
        case .legalDetails:
            return "Dokumenty i polityki"
        case .fulfillment:
            return "Ustawienia sprzedaży"
        case .openingHours:
            return "Godziny otwarcia"
        case .orderSettings:
            return "Przyjmowanie zamówień"
        case .firstMenu:
            return "Pierwsza kategoria i pozycja"
        case .finish:
            return "Gotowe do startu"
        }
    }

    private var progressLabel: String {
        let total = Double(OnboardingStep.allCases.count)
        let current = Double(step.rawValue + 1)
        return "\(Int((current / total) * 100))%"
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch step {
        case .basicInfo:
            BasicInfoStepView(
                businessName: binding(\.businessName),
                address: binding(\.address),
                phone: binding(\.phone)
            )

        case .publicLink:
            PublicLinkStepView(
                username: usernameBinding,
                accentSoft: accentSoft,
                validationState: auth.usernameValidationState,
                isBusy: auth.isLoading,
                onCheckNow: {
                    await auth.validateUsernameAvailability(force: true)
                }
            )

        case .brandColor:
            BrandColorStepView(
                accentColorHex: binding(\.accentColorHex)
            )

        case .legalDetails:
            LegalDetailsStepView(
                legalBusinessName: binding(\.legalBusinessName),
                businessDisplayName: binding(\.businessDisplayName),
                nip: binding(\.nip),
                addressLine1: binding(\.addressLine1),
                addressLine2: binding(\.addressLine2),
                postalCode: binding(\.postalCode),
                city: binding(\.city),
                country: binding(\.country),
                contactEmail: binding(\.contactEmail),
                contactPhone: binding(\.contactPhone),
                complaintEmail: binding(\.complaintEmail),
                complaintPhone: binding(\.complaintPhone)
            )

        case .fulfillment:
            FulfillmentStepView(
                pickupAvailable: binding(\.pickupAvailable),
                deliveryAvailable: binding(\.deliveryAvailable),
                deliveryArea: binding(\.deliveryArea),
                deliveryPricePerKm: binding(\.deliveryPricePerKm),
                cashPaymentAvailable: binding(\.cashPaymentAvailable),
                cardPaymentAvailable: binding(\.cardPaymentAvailable),
                blikPaymentAvailable: binding(\.blikPaymentAvailable),
                accentColor: accentColor
            )

        case .openingHours:
            OpeningHoursStepView(
                days: binding(\.days),
                accentColor: accentColor
            )

        case .orderSettings:
            OrderSettingsStepView(
                isAcceptingOrders: binding(\.isAcceptingOrders),
                smsConfirmationEnabled: binding(\.smsConfirmationEnabled),
                slotIntervalMinutes: binding(\.slotIntervalMinutes),
                accentColor: accentColor
            )

        case .firstMenu:
            FirstMenuStepView(
                categoryName: binding(\.categoryName),
                firstItemName: binding(\.firstItemName),
                firstItemDescription: binding(\.firstItemDescription),
                firstItemPrice: binding(\.firstItemPrice),
                firstItemPhoto: $firstItemPhoto,
                firstItemImageData: $firstItemImageData
            )

        case .finish:
            FinishStepView(draft: draft)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            if let errorMessage = auth.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.wix(13, wixWeight: .medium))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            if let noticeMessage = auth.noticeMessage, !noticeMessage.isEmpty {
                Text(noticeMessage)
                    .font(.wix(13, wixWeight: .medium))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            HStack(spacing: 12) {
                if step.rawValue > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            step = OnboardingStep(rawValue: step.rawValue - 1) ?? .basicInfo
                        }
                    } label: {
                        Text("Wstecz")
                            .font(.wix(16, wixWeight: .semiBold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            )
                    }
                }

                Button {
                    guard !isSubmittingFinish else { return }

                    Task {
                        if step == .finish {
                            isSubmittingFinish = true
                        }

                        await nextAction()

                        isSubmittingFinish = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if (auth.isLoading || isSubmittingFinish) && step == .finish {
                            ProgressView()
                                .tint(.black)
                                .scaleEffect(0.9)
                        }

                        Text(primaryButtonTitle)
                            .font(.wix(16, wixWeight: .semiBold))
                            .foregroundStyle(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(isCurrentStepValid ? accentColor : Color.black.opacity(0.16))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(isCurrentStepValid ? accentColor.opacity(0.5) : .clear, lineWidth: 1)
                    )
                }
                .disabled(!isCurrentStepValid || auth.isLoading || isSubmittingFinish)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 18)
        }
        .background(
            Rectangle()
                .fill(Color.white)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.black.opacity(0.05))
                        .frame(height: 1)
                }
        )
    }

    private var primaryButtonTitle: String {
        if step == .finish {
            return auth.isLoading ? "Tworzenie..." : "Utwórz panel"
        } else {
            return "Dalej"
        }
    }

    private var isCurrentStepValid: Bool {
        switch step {
        case .basicInfo:
            return draft.businessName.trimmed.count >= 2 &&
                   draft.address.trimmed.count >= 3 &&
                   draft.phone.trimmed.count >= 6

        case .publicLink:
            return draft.username.slugified.count >= 3 &&
                   auth.usernameValidationState == .available

        case .brandColor:
            return draft.accentColorHex.trimmed.hasPrefix("#") &&
                   draft.accentColorHex.trimmed.count == 7

        case .legalDetails:
            return draft.legalBusinessName.trimmed.count >= 2 &&
                   draft.businessDisplayName.trimmed.count >= 2 &&
                   draft.nip.trimmed.count >= 10 &&
                   draft.addressLine1.trimmed.count >= 3 &&
                   draft.postalCode.trimmed.count >= 3 &&
                   draft.city.trimmed.count >= 2 &&
                   draft.contactEmail.trimmed.contains("@") &&
                   draft.contactPhone.trimmed.count >= 6

        case .fulfillment:
            let hasPaymentMethod = draft.cashPaymentAvailable || draft.cardPaymentAvailable || draft.blikPaymentAvailable
            let hasFulfillment = draft.pickupAvailable || draft.deliveryAvailable
            let deliveryAreaOk = !draft.deliveryAvailable || draft.deliveryArea.trimmed.count >= 2
            let deliveryPriceOk = !draft.deliveryAvailable || Double(draft.deliveryPricePerKm.replacingOccurrences(of: ",", with: ".")) != nil

            return hasFulfillment && hasPaymentMethod && deliveryAreaOk && deliveryPriceOk

        case .openingHours:
            return draft.days.contains(where: { !$0.isClosed })

        case .orderSettings:
            return [5, 10, 15, 20, 30, 45, 60].contains(draft.slotIntervalMinutes)

        case .firstMenu:
            return draft.categoryName.trimmed.count >= 2 &&
                   draft.firstItemName.trimmed.count >= 2 &&
                   Double(draft.firstItemPrice.replacingOccurrences(of: ",", with: ".")) != nil

        case .finish:
            return true
        }
    }

    private func nextAction() async {
        if auth.isLoading {
            return
        }

        auth.errorMessage = nil

        if step == .basicInfo {
            var updatedDraft = draft

            if updatedDraft.businessDisplayName.trimmed.isEmpty {
                updatedDraft.businessDisplayName = updatedDraft.businessName
            }

            if updatedDraft.contactPhone.trimmed.isEmpty {
                updatedDraft.contactPhone = updatedDraft.phone
            }

            draft = updatedDraft
        }

        if step == .publicLink {
            let canContinue = await auth.ensureUsernameValidForNextStep()
            guard canContinue else { return }
        }

        if step == .firstMenu {
            var updatedDraft = draft
            updatedDraft.firstItemImageData = firstItemImageData
            draft = updatedDraft
        }

        if step == .finish {
            auth.onboardingDraft = draft
            await auth.completeOnboarding()
        } else {
            withAnimation(.easeInOut(duration: 0.22)) {
                step = OnboardingStep(rawValue: step.rawValue + 1) ?? .finish
            }
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<OnboardingDraft, Value>) -> Binding<Value> {
        Binding(
            get: { auth.onboardingDraft[keyPath: keyPath] },
            set: { auth.onboardingDraft[keyPath: keyPath] = $0 }
        )
    }
}

private struct BasicInfoStepView: View {
    @Binding var businessName: String
    @Binding var address: String
    @Binding var phone: String

    private let accentSoft = Color(lmHex: "#5BE47B").opacity(0.14)

    var body: some View {
        VStack(spacing: 18) {
            LMHeroCard(
                title: "Profil lokalu",
                subtitle: "Dodaj podstawowe dane widoczne na stronie lokalu i w panelu"
            ) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(accentSoft)
                            .frame(width: 52, height: 52)

                        Image(systemName: "storefront.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.black)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Podstawowe informacje")
                            .font(.wix(17, wixWeight: .semiBold))
                            .foregroundStyle(.black)

                        Text("Nazwa, adres i numer telefonu będą widoczne dla klientów")
                            .font(.wix(13, wixWeight: .regular))
                            .foregroundStyle(.black.opacity(0.58))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }
                .padding(14)
                .background(accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            LMCard {
                VStack(spacing: 14) {
                    LMInputField(title: "Nazwa lokalu", text: $businessName)
                    LMInputField(title: "Adres", text: $address)
                    LMInputField(title: "Telefon", text: $phone, keyboard: .phonePad)
                }
            }
        }
    }
}

private struct PublicLinkStepView: View {
    @Binding var username: String
    let accentSoft: Color
    let validationState: AuthViewModel.UsernameValidationState
    let isBusy: Bool
    let onCheckNow: () async -> Void

    private var preview: String {
        username.slugified.isEmpty ? "twoj-lokal" : username.slugified
    }

    private var helperText: String {
        switch validationState {
        case .idle:
            return "Użyj małych liter, cyfr i myślników"
        case .typing:
            return "Za chwilę sprawdzimy dostępność linku"
        case .checking:
            return "Sprawdzanie dostępności..."
        case .available:
            return "Ten link jest dostępny"
        case .taken:
            return "Ten link jest już zajęty"
        case .invalid(let message):
            return message
        case .error(let message):
            return message
        }
    }

    private var helperColor: Color {
        switch validationState {
        case .available:
            return Color.green
        case .taken, .invalid, .error:
            return Color.red
        default:
            return Color.black.opacity(0.48)
        }
    }

    private var borderColor: Color {
        switch validationState {
        case .available:
            return Color.green.opacity(0.25)
        case .taken, .invalid, .error:
            return Color.red.opacity(0.25)
        default:
            return Color.clear
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            LMHeroCard(
                title: "Wybierz swój link",
                subtitle: "To będzie adres, który udostępnisz klientom w social media i wiadomościach"
            ) {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        LMInputField(title: "Nazwa w linku", text: $username)

                        HStack(spacing: 8) {
                            if case .checking = validationState {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }

                            Text(helperText)
                                .font(.wix(13, wixWeight: .medium))
                                .foregroundStyle(helperColor)

                            Spacer()
                        }
                    }
                    .padding(12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Podgląd")
                            .font(.wix(13, wixWeight: .medium))
                            .foregroundStyle(.black.opacity(0.45))

                        HStack(spacing: 10) {
                            Image(systemName: "link")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.black)

                            Text("lamenu.pl/\(preview)")
                                .font(.wix(18, wixWeight: .semiBold))
                                .foregroundStyle(.black)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Spacer()
                        }
                        .padding(16)
                        .background(accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }
            }

            LMInfoCard(
                icon: "sparkles",
                title: "Krótko i czytelnie",
                subtitle: "Prosty link łatwiej zapamiętać i lepiej wygląda w internecie"
            )
        }
        .task(id: username) {
            let normalized = username.slugified
            guard !normalized.isEmpty else { return }
            guard normalized.count >= 3 else { return }

            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }

            await onCheckNow()
        }
    }
}

private struct BrandColorStepView: View {
    @Binding var accentColorHex: String

    private let presets: [String] = [
        "#FF0043",
        "#FE592A",
        "#5BE47B",
        "#111111",
        "#3B82F6",
        "#8B5CF6"
    ]

    private var selectedColorBinding: Binding<Color> {
        Binding(
            get: { Color(lmHex: accentColorHex) },
            set: { newValue in
                accentColorHex = newValue.toHexString() ?? "#FF0043"
            }
        )
    }

    var body: some View {
        VStack(spacing: 18) {
            LMHeroCard(
                title: "Wybierz kolor firmowy",
                subtitle: "Ten kolor będzie używany w przyciskach, akcentach i elementach marki"
            ) {
                EmptyView()
            }

            LMCard {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Kolor marki")
                        .font(.wix(18, wixWeight: .semiBold))
                        .foregroundStyle(.black)

                    ColorPicker("Wybierz kolor", selection: selectedColorBinding, supportsOpacity: false)
                        .font(.wix(16, wixWeight: .medium))
                        .foregroundStyle(.black)

                    HStack(spacing: 12) {
                        ForEach(presets, id: \.self) { hex in
                            Button {
                                accentColorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(lmHex: hex))
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                accentColorHex.lowercased() == hex.lowercased()
                                                ? Color.black
                                                : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(lmHex: accentColorHex))
                            .frame(width: 62, height: 62)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Wybrany kolor")
                                .font(.wix(13, wixWeight: .medium))
                                .foregroundStyle(.black.opacity(0.45))

                            Text(accentColorHex.uppercased())
                                .font(.wix(18, wixWeight: .bold))
                                .foregroundStyle(.black)
                        }

                        Spacer()
                    }
                    .padding(14)
                    .background(Color.black.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }

            LMInfoCard(
                icon: "paintpalette.fill",
                title: "Kolor marki",
                subtitle: "Możesz go później zmienić w panelu ustawień profilu"
            )
        }
    }
}

private struct LegalDetailsStepView: View {
    @Binding var legalBusinessName: String
    @Binding var businessDisplayName: String
    @Binding var nip: String
    @Binding var addressLine1: String
    @Binding var addressLine2: String
    @Binding var postalCode: String
    @Binding var city: String
    @Binding var country: String
    @Binding var contactEmail: String
    @Binding var contactPhone: String
    @Binding var complaintEmail: String
    @Binding var complaintPhone: String

    var body: some View {
        VStack(spacing: 18) {
            LMHeroCard(
                title: "Dane do dokumentów",
                subtitle: "Te informacje pojawią się w danych sprzedawcy, regulaminie zamówień i polityce prywatności lokalu"
            ) {
                EmptyView()
            }

            LMCard {
                VStack(spacing: 14) {
                    LMInputField(title: "Pełna nazwa firmy", text: $legalBusinessName)
                    LMInputField(title: "Nazwa widoczna dla klientów", text: $businessDisplayName)
                    LMInputField(title: "NIP", text: $nip, keyboard: .numberPad)
                }
            }

            LMCard {
                VStack(spacing: 14) {
                    LMInputField(title: "Adres — linia 1", text: $addressLine1)
                    LMInputField(title: "Adres — linia 2", text: $addressLine2)
                    LMInputField(title: "Kod pocztowy", text: $postalCode)
                    LMInputField(title: "Miasto", text: $city)
                    LMInputField(title: "Kraj", text: $country)
                }
            }

            LMCard {
                VStack(spacing: 14) {
                    LMInputField(title: "E-mail kontaktowy", text: $contactEmail, keyboard: .emailAddress)
                    LMInputField(title: "Telefon kontaktowy", text: $contactPhone, keyboard: .phonePad)
                    LMInputField(title: "E-mail reklamacyjny", text: $complaintEmail, keyboard: .emailAddress)
                    LMInputField(title: "Telefon reklamacyjny", text: $complaintPhone, keyboard: .phonePad)
                }
            }
        }
    }
}

private struct FulfillmentStepView: View {
    @Binding var pickupAvailable: Bool
    @Binding var deliveryAvailable: Bool
    @Binding var deliveryArea: String
    @Binding var deliveryPricePerKm: String
    @Binding var cashPaymentAvailable: Bool
    @Binding var cardPaymentAvailable: Bool
    @Binding var blikPaymentAvailable: Bool
    let accentColor: Color

    var body: some View {
        VStack(spacing: 18) {
            LMHeroCard(
                title: "Realizacja i płatność",
                subtitle: "Ustaw dostępne formy odbioru, dostawę i metody płatności"
            ) {
                EmptyView()
            }

            LMCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Formy realizacji")
                        .font(.wix(18, wixWeight: .semiBold))
                        .foregroundStyle(.black)

                    LMToggleRow(
                        title: "Odbiór osobisty",
                        subtitle: "Klient odbiera zamówienie na miejscu",
                        isOn: $pickupAvailable,
                        tint: accentColor
                    )

                    LMToggleRow(
                        title: "Dostawa",
                        subtitle: "Klient może zamówić z dostawą",
                        isOn: $deliveryAvailable,
                        tint: accentColor
                    )

                    if deliveryAvailable {
                        LMInputField(title: "Obszar dostawy", text: $deliveryArea)

                        LMInputField(
                            title: "Cena za 1 km",
                            text: $deliveryPricePerKm,
                            keyboard: .decimalPad
                        )

                        Text("Ta stawka będzie widoczna przy zamówieniu z dostawą")
                            .font(.wix(13, wixWeight: .regular))
                            .foregroundStyle(.black.opacity(0.5))
                    }
                }
            }

            LMCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Metody płatności")
                        .font(.wix(18, wixWeight: .semiBold))
                        .foregroundStyle(.black)

                    LMToggleRow(
                        title: "Gotówka",
                        subtitle: "Płatność gotówką przy odbiorze lub dostawie",
                        isOn: $cashPaymentAvailable,
                        tint: accentColor
                    )

                    LMToggleRow(
                        title: "Karta",
                        subtitle: "Płatność kartą",
                        isOn: $cardPaymentAvailable,
                        tint: accentColor
                    )

                    LMToggleRow(
                        title: "BLIK",
                        subtitle: "Płatność BLIK",
                        isOn: $blikPaymentAvailable,
                        tint: accentColor
                    )
                }
            }
        }
    }
}

private struct OpeningHoursStepView: View {
    @Binding var days: [DayHoursDraft]
    let accentColor: Color

    var body: some View {
        VStack(spacing: 14) {
            LMHeroCard(
                title: "Godziny otwarcia",
                subtitle: "Klienci od razu zobaczą, kiedy lokal przyjmuje zamówienia"
            ) {
                EmptyView()
            }

            ForEach($days) { $day in
                LMCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(day.title)
                                    .font(.wix(18, wixWeight: .semiBold))
                                    .foregroundStyle(.black)

                                Text(day.isClosed ? "Lokal zamknięty" : "Lokal otwarty")
                                    .font(.wix(13, wixWeight: .regular))
                                    .foregroundStyle(.black.opacity(0.48))
                            }

                            Spacer()

                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { !day.isClosed },
                                    set: { day.isClosed = !$0 }
                                )
                            )
                            .labelsHidden()
                            .tint(accentColor)
                        }

                        if !day.isClosed {
                            HStack(spacing: 12) {
                                LMTimePickerCard(title: "Otwarcie", date: $day.openDate)
                                LMTimePickerCard(title: "Zamknięcie", date: $day.closeDate)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct OrderSettingsStepView: View {
    @Binding var isAcceptingOrders: Bool
    @Binding var smsConfirmationEnabled: Bool
    @Binding var slotIntervalMinutes: Int
    let accentColor: Color

    private let slotOptions = [5, 10, 15, 20, 30, 45, 60]

    var body: some View {
        VStack(spacing: 18) {
            LMHeroCard(
                title: "Przyjmowanie zamówień",
                subtitle: "Włącz lub wyłącz zamówienia, ustaw odstęp między slotami i wybierz, czy klient ma dostać SMS po złożeniu zamówienia"
            ) {
                EmptyView()
            }

            LMCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Status zamówień")
                        .font(.wix(18, wixWeight: .semiBold))
                        .foregroundStyle(.black)

                    LMToggleRow(
                        title: "Zamówienia przyjmowane",
                        subtitle: "Gdy wyłączone, klienci zobaczą informację, że lokal chwilowo nie przyjmuje zamówień",
                        isOn: $isAcceptingOrders,
                        tint: accentColor
                    )
                }
            }

            LMCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Powiadomienia SMS")
                        .font(.wix(18, wixWeight: .semiBold))
                        .foregroundStyle(.black)

                    LMToggleRow(
                        title: "SMS z potwierdzeniem zamówienia",
                        subtitle: "Po złożeniu zamówienia klient dostanie wiadomość SMS na podany numer telefonu",
                        isOn: $smsConfirmationEnabled,
                        tint: accentColor
                    )
                }
            }

            LMCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Sloty czasowe")
                        .font(.wix(18, wixWeight: .semiBold))
                        .foregroundStyle(.black)

                    Text("Odstęp między slotami")
                        .font(.wix(13, wixWeight: .medium))
                        .foregroundStyle(.black.opacity(0.45))

                    Menu {
                        ForEach(slotOptions, id: \.self) { value in
                            Button("\(value) min") {
                                slotIntervalMinutes = value
                            }
                        }
                    } label: {
                        HStack {
                            Text("\(slotIntervalMinutes) min")
                                .font(.wix(16, wixWeight: .semiBold))
                                .foregroundStyle(.black)

                            Spacer()

                            Image(systemName: "chevron.down")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.black.opacity(0.5))
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 56)
                        .background(Color.black.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct FirstMenuStepView: View {
    @Binding var categoryName: String
    @Binding var firstItemName: String
    @Binding var firstItemDescription: String
    @Binding var firstItemPrice: String
    @Binding var firstItemPhoto: PhotosPickerItem?
    @Binding var firstItemImageData: Data?

    var body: some View {
        VStack(spacing: 18) {
            LMHeroCard(
                title: "Pierwsza kategoria i pierwsza pozycja",
                subtitle: "Najpierw utwórz kategorię, a potem dodaj do niej pierwszą pozycję ze zdjęciem"
            ) {
                EmptyView()
            }

            LMCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Kategoria")
                        .font(.wix(18, wixWeight: .semiBold))
                        .foregroundStyle(.black)

                    LMInputField(title: "Utwórz kategorię", text: $categoryName)
                }
            }

            LMCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Pierwsza pozycja")
                        .font(.wix(18, wixWeight: .semiBold))
                        .foregroundStyle(.black)

                    PhotosPicker(selection: $firstItemPhoto, matching: .images) {
                        HStack(spacing: 16) {
                            Group {
                                if let firstItemImageData,
                                   let uiImage = UIImage(data: firstItemImageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .fill(Color.black.opacity(0.06))

                                        VStack(spacing: 8) {
                                            Image(systemName: "photo.fill")
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundStyle(.black)

                                            Text("Dodaj zdjęcie")
                                                .font(.wix(13, wixWeight: .semiBold))
                                                .foregroundStyle(.black)
                                        }
                                    }
                                }
                            }
                            .frame(width: 92, height: 92)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Zdjęcie pozycji")
                                    .font(.wix(17, wixWeight: .semiBold))
                                    .foregroundStyle(.black)

                                Text("Klienci zobaczą je na stronie menu")
                                    .font(.wix(14, wixWeight: .regular))
                                    .foregroundStyle(.black.opacity(0.58))

                                Text("Opcjonalne")
                                    .font(.wix(12, wixWeight: .semiBold))
                                    .foregroundStyle(.black.opacity(0.42))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.black.opacity(0.05))
                                    .clipShape(Capsule())
                            }

                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color.black.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }

                    LMInputField(title: "Nazwa pozycji", text: $firstItemName)
                    LMInputField(title: "Opis pozycji", text: $firstItemDescription)
                    LMInputField(title: "Cena", text: $firstItemPrice, keyboard: .decimalPad)
                }
            }

            LMInfoCard(
                icon: "sparkles",
                title: "Dobry start",
                subtitle: "Po zakończeniu dodasz kolejne kategorie, więcej pozycji i więcej zdjęć"
            )
        }
    }
}

private struct FinishStepView: View {
    let draft: OnboardingDraft

    var body: some View {
        VStack(spacing: 16) {
            LMHeroCard(
                title: "Wszystko gotowe",
                subtitle: "Sprawdź najważniejsze dane przed utworzeniem panelu"
            ) {
                EmptyView()
            }

            summaryCard(
                title: "Lokal",
                rows: [
                    ("Nazwa", draft.businessName),
                    ("Adres", draft.address),
                    ("Telefon", draft.phone.trimmed.isEmpty ? "—" : draft.phone)
                ]
            )

            summaryCard(
                title: "Link publiczny",
                rows: [
                    ("Link", "lamenu.pl/\(draft.username.slugified)")
                ]
            )

            summaryCard(
                title: "Kolor marki",
                rows: [
                    ("Kolor", draft.accentColorHex.uppercased())
                ]
            )

            summaryCard(
                title: "Dane prawne",
                rows: [
                    ("Firma", draft.legalBusinessName),
                    ("NIP", draft.nip),
                    ("Adres", legalAddressSummary),
                    ("E-mail", draft.contactEmail),
                    ("Telefon", draft.contactPhone)
                ]
            )

            summaryCard(
                title: "Realizacja i płatność",
                rows: [
                    ("Odbiór", draft.pickupAvailable ? "Tak" : "Nie"),
                    ("Dostawa", draft.deliveryAvailable ? "Tak" : "Nie"),
                    ("Obszar dostawy", draft.deliveryAvailable ? draft.deliveryArea : "—"),
                    ("Cena dostawy / 1 km", draft.deliveryAvailable ? "\(draft.deliveryPricePerKm) zł" : "—"),
                    ("Gotówka", draft.cashPaymentAvailable ? "Tak" : "Nie"),
                    ("Karta", draft.cardPaymentAvailable ? "Tak" : "Nie"),
                    ("BLIK", draft.blikPaymentAvailable ? "Tak" : "Nie")
                ]
            )

            summaryCard(
                title: "Przyjmowanie zamówień",
                rows: [
                    ("Status", draft.isAcceptingOrders ? "Włączone" : "Wyłączone"),
                    ("SMS", draft.smsConfirmationEnabled ? "Włączone" : "Wyłączone"),
                    ("Sloty", "\(draft.slotIntervalMinutes) min")
                ]
            )
            
            summaryCard(
                title: "Pierwsza kategoria i pozycja",
                rows: [
                    ("Kategoria", draft.categoryName),
                    ("Pozycja", draft.firstItemName),
                    ("Cena", "\(draft.firstItemPrice) zł")
                ]
            )
        }
    }

    private var legalAddressSummary: String {
        let secondLine = draft.addressLine2.trimmed.isEmpty ? "" : ", \(draft.addressLine2)"
        return "\(draft.addressLine1)\(secondLine), \(draft.postalCode) \(draft.city)"
    }

    private func summaryCard(title: String, rows: [(String, String)]) -> some View {
        LMCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.wix(20, wixWeight: .bold))
                    .foregroundStyle(.black)

                VStack(spacing: 14) {
                    ForEach(rows, id: \.0) { row in
                        HStack(alignment: .top, spacing: 12) {
                            Text(row.0)
                                .font(.wix(14, wixWeight: .medium))
                                .foregroundStyle(.black.opacity(0.45))

                            Spacer(minLength: 12)

                            Text(row.1)
                                .font(.wix(15, wixWeight: .semiBold))
                                .foregroundStyle(.black)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
        }
    }
}

private struct LMHeroCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.wix(24, wixWeight: .bold))
                    .foregroundStyle(.black)
                    .tracking(-0.3)

                Text(subtitle)
                    .font(.wix(14, wixWeight: .regular))
                    .foregroundStyle(.black.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct LMCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
    }
}

private struct LMInfoCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.05))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.black)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.wix(16, wixWeight: .semiBold))
                    .foregroundStyle(.black)

                Text(subtitle)
                    .font(.wix(14, wixWeight: .regular))
                    .foregroundStyle(.black.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct LMInputField: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.wix(13, wixWeight: .medium))
                .foregroundStyle(.black.opacity(0.45))

            TextField(title, text: $text)
                .font(.wix(16, wixWeight: .medium))
                .foregroundStyle(.black)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboard)
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(Color.black.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

private struct LMToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.wix(16, wixWeight: .semiBold))
                    .foregroundStyle(.black)

                Text(subtitle)
                    .font(.wix(13, wixWeight: .regular))
                    .foregroundStyle(.black.opacity(0.52))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(tint)
        }
        .padding(16)
        .background(Color.black.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct LMTimePickerCard: View {
    let title: String
    @Binding var date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.wix(13, wixWeight: .medium))
                .foregroundStyle(.black.opacity(0.45))

            DatePicker(
                "",
                selection: $date,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .frame(height: 54)
            .background(Color.black.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension Font {
    static func wix(_ size: CGFloat, wixWeight: WixWeight = .regular) -> Font {
        .custom(wixWeight.fontName, size: size)
    }
}

private enum WixWeight {
    case regular
    case medium
    case semiBold
    case bold
    case extraBold

    var fontName: String {
        switch self {
        case .regular:
            return "WixMadeforDisplay-Regular"
        case .medium:
            return "WixMadeforDisplay-Medium"
        case .semiBold:
            return "WixMadeforDisplay-SemiBold"
        case .bold:
            return "WixMadeforDisplay-Bold"
        case .extraBold:
            return "WixMadeforDisplay-ExtraBold"
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var slugified: String {
        trimmed
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .replacingOccurrences(of: "^-+|-+$", with: "", options: .regularExpression)
    }
}

private extension Color {
    init(lmHex: String) {
        let hex = lmHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (
                255,
                (int >> 8) * 17,
                (int >> 4 & 0xF) * 17,
                (int & 0xF) * 17
            )
        case 6:
            (a, r, g, b) = (
                255,
                int >> 16,
                int >> 8 & 0xFF,
                int & 0xFF
            )
        case 8:
            (a, r, g, b) = (
                int >> 24,
                int >> 16 & 0xFF,
                int >> 8 & 0xFF,
                int & 0xFF
            )
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHexString() -> String? {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }

        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
    }
}
