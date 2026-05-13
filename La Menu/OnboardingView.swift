import SwiftUI
import PhotosUI
import UIKit

private enum OnboardingText {
    static func t(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }

    static let step = "onboarding.step"
    static let of = "onboarding.of"

    static let back = "onboarding.button.back"
    static let next = "onboarding.button.next"
    static let createPanel = "onboarding.button.create_panel"
    static let creating = "onboarding.button.creating"

    static let yes = "common.yes"
    static let no = "common.no"
    static let enabled = "common.enabled"
    static let disabled = "common.disabled"
    static let emptyDash = "common.empty_dash"
    static let optional = "common.optional"
    static let minutesShort = "common.minutes_short"
    static let currencyPln = "common.currency_pln"
}

struct OnboardingView: View {
    @Environment(AuthViewModel.self) private var auth

    @State private var logoPhoto: PhotosPickerItem?
    @State private var logoImageData: Data?

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
    
    private var publicDomain: String {
        switch draft.publicCountry {
        case "uk":
            return "lamenu.uk"
        default:
            return "lamenu.pl"
        }
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
                log("username changed -> raw: '\(newValue)' | slugified: '\(newValue.slugified)'")
            }
        )
    }

    private var nipBinding: Binding<String> {
        Binding(
            get: { auth.onboardingDraft.nip },
            set: { newValue in
                auth.onboardingDraft.nip = newValue
                log("NIP changed -> raw: '\(newValue)' | trimmed: '\(newValue.trimmed)' | isEmpty: \(newValue.trimmed.isEmpty)")
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
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 132)
                    }
                    .id(step)
                    .background(Color.white)
                }

                bottomBar
            }
            .background(Color.white)
            .navigationBarBackButtonHidden(true)
        }
        .background(Color.white)
        .task(id: logoPhoto) {
            guard let logoPhoto else { return }

            log("loading logo photo")

            do {
                logoImageData = try await logoPhoto.loadTransferable(type: Data.self)
                log("logo photo loaded -> \(logoImageData != nil) | bytes: \(logoImageData?.count ?? 0)")
            } catch {
                log("logo photo loading failed -> \(error.localizedDescription)")
            }
        }
        .task(id: firstItemPhoto) {
            guard let firstItemPhoto else { return }

            log("loading first item photo")

            do {
                firstItemImageData = try await firstItemPhoto.loadTransferable(type: Data.self)
                log("first item photo loaded -> \(firstItemImageData != nil) | bytes: \(firstItemImageData?.count ?? 0)")
            } catch {
                log("first item photo loading failed -> \(error.localizedDescription)")
            }
        }
        .onAppear {
            log("onAppear")
            logDraftState(prefix: "initial draft onAppear")

            if logoImageData == nil {
                logoImageData = draft.logoImageData
                log("restored logoImageData from draft -> \(logoImageData != nil) | bytes: \(logoImageData?.count ?? 0)")
            }

            if firstItemImageData == nil {
                firstItemImageData = draft.firstItemImageData
                log("restored firstItemImageData from draft -> \(firstItemImageData != nil) | bytes: \(firstItemImageData?.count ?? 0)")
            }
        }
        .onChange(of: step) { oldStep, newStep in
            log("step changed -> old: \(oldStep.rawValue) \(oldStep.title) | new: \(newStep.rawValue) \(newStep.title)")
            logDraftState(prefix: "draft after step change")
        }
        .onChange(of: auth.errorMessage) { _, newValue in
            if let newValue, !newValue.isEmpty {
                log("auth.errorMessage -> \(newValue)")
            } else {
                log("auth.errorMessage cleared")
            }
        }
        .onChange(of: auth.noticeMessage) { _, newValue in
            if let newValue, !newValue.isEmpty {
                log("auth.noticeMessage -> \(newValue)")
            } else {
                log("auth.noticeMessage cleared")
            }
        }
        .onChange(of: auth.isLoading) { _, newValue in
            log("auth.isLoading -> \(newValue)")
        }
        .onChange(of: auth.profile != nil) { _, newValue in
            log("auth.profile exists changed -> \(newValue)")
            log("auth.profile id -> \(auth.profile?.id.uuidString ?? "nil")")
        }
    }

    private var topSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(stepEyebrow)
                    .font(.wix(12, wixWeight: .semiBold))
                    .foregroundStyle(.black.opacity(0.42))
                    .tracking(0.2)

                Text(stepTitle)
                    .font(.wix(32, wixWeight: .bold))
                    .foregroundStyle(.black)
                    .tracking(-0.7)

                Text(stepSubtitle)
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
                    Text("\(OnboardingText.t(OnboardingText.step)) \(step.rawValue + 1) \(OnboardingText.t(OnboardingText.of)) \(OnboardingStep.allCases.count)")
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
            return OnboardingText.t("onboarding.eyebrow.basic_info")
        case .publicLink:
            return OnboardingText.t("onboarding.eyebrow.public_link")
        case .brandColor:
            return OnboardingText.t("onboarding.eyebrow.brand_color")
        case .legalDetails:
            return OnboardingText.t("onboarding.eyebrow.legal_details")
        case .fulfillment:
            return OnboardingText.t("onboarding.eyebrow.fulfillment")
        case .openingHours:
            return OnboardingText.t("onboarding.eyebrow.opening_hours")
        case .orderSettings:
            return OnboardingText.t("onboarding.eyebrow.order_settings")
        case .firstMenu:
            return OnboardingText.t("onboarding.eyebrow.first_menu")
        case .finish:
            return OnboardingText.t("onboarding.eyebrow.finish")
        }
    }

    private var stepTitle: String {
        switch step {
        case .basicInfo:
            return OnboardingText.t("onboarding.step.basic_info.title")
        case .publicLink:
            return OnboardingText.t("onboarding.step.public_link.title")
        case .brandColor:
            return OnboardingText.t("onboarding.step.brand_color.title")
        case .legalDetails:
            return OnboardingText.t("onboarding.step.legal_details.title")
        case .fulfillment:
            return OnboardingText.t("onboarding.step.fulfillment.title")
        case .openingHours:
            return OnboardingText.t("onboarding.step.opening_hours.title")
        case .orderSettings:
            return OnboardingText.t("onboarding.step.order_settings.title")
        case .firstMenu:
            return OnboardingText.t("onboarding.step.first_menu.title")
        case .finish:
            return OnboardingText.t("onboarding.step.finish.title")
        }
    }

    private var stepSubtitle: String {
        switch step {
        case .basicInfo:
            return OnboardingText.t("onboarding.step.basic_info.subtitle")
        case .publicLink:
            return OnboardingText.t("onboarding.step.public_link.subtitle")
        case .brandColor:
            return OnboardingText.t("onboarding.step.brand_color.subtitle")
        case .legalDetails:
            return OnboardingText.t("onboarding.step.legal_details.subtitle")
        case .fulfillment:
            return OnboardingText.t("onboarding.step.fulfillment.subtitle")
        case .openingHours:
            return OnboardingText.t("onboarding.step.opening_hours.subtitle")
        case .orderSettings:
            return OnboardingText.t("onboarding.step.order_settings.subtitle")
        case .firstMenu:
            return OnboardingText.t("onboarding.step.first_menu.subtitle")
        case .finish:
            return OnboardingText.t("onboarding.step.finish.subtitle")
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
                phone: binding(\.phone),
                logoPhoto: $logoPhoto,
                logoImageData: $logoImageData
            )

        case .publicLink:
            PublicLinkStepView(
                username: usernameBinding,
                domain: publicDomain,
                accentSoft: accentSoft,
                validationState: auth.usernameValidationState,
                isBusy: auth.isLoading,
                onCheckNow: {
                    log("manual username check requested")
                    await auth.validateUsernameAvailability(force: true)
                    log("username validation state after check -> \(String(describing: auth.usernameValidationState))")
                }
            )

        case .brandColor:
            BrandColorStepView(
                accentColorHex: binding(\.accentColorHex),
                publicCountry: binding(\.publicCountry),
                publicLanguage: binding(\.publicLanguage),
                publicCurrency: binding(\.publicCurrency)
            )

        case .legalDetails:
            LegalDetailsStepView(
                legalBusinessName: binding(\.legalBusinessName),
                businessDisplayName: binding(\.businessDisplayName),
                nip: nipBinding,
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
            FinishStepView(
                draft: draft,
                publicDomain: publicDomain,
                logoImageData: logoImageData
            )
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
                        log("back tapped from step \(step.rawValue) \(step.title)")

                        withAnimation(.easeInOut(duration: 0.22)) {
                            step = OnboardingStep(rawValue: step.rawValue - 1) ?? .basicInfo
                        }
                    } label: {
                        Text(OnboardingText.t(OnboardingText.back))
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
                    guard !isSubmittingFinish else {
                        log("primary button ignored because isSubmittingFinish == true")
                        return
                    }

                    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                    log("PRIMARY BUTTON TAPPED")
                    log("step -> \(step.rawValue) \(step.title)")
                    log("button title -> \(primaryButtonTitle)")
                    log("isCurrentStepValid -> \(isCurrentStepValid)")
                    log("auth.isLoading -> \(auth.isLoading)")
                    log("isSubmittingFinish -> \(isSubmittingFinish)")
                    log("NIP at button tap -> raw: '\(draft.nip)' | trimmed: '\(draft.nip.trimmed)' | isEmpty: \(draft.nip.trimmed.isEmpty)")
                    logValidationStateForCurrentStep()
                    logDraftState(prefix: "draft at primary button tap")
                    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

                    Task {
                        if step == .finish {
                            isSubmittingFinish = true
                            log("finish submission started from final button")
                        }

                        await nextAction()

                        isSubmittingFinish = false
                        log("finish submission ended from final button")
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
            return auth.isLoading
            ? OnboardingText.t(OnboardingText.creating)
            : OnboardingText.t(OnboardingText.createPanel)
        } else {
            return OnboardingText.t(OnboardingText.next)
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
                   draft.accentColorHex.trimmed.count == 7 &&
                   ["pl", "uk"].contains(draft.publicCountry) &&
                   ["pl", "en"].contains(draft.publicLanguage) &&
                   ["PLN", "EUR", "USD", "GBP", "CAD", "UAH"].contains(draft.publicCurrency)

        case .legalDetails:
            return draft.legalBusinessName.trimmed.count >= 2 &&
                   draft.businessDisplayName.trimmed.count >= 2 &&
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
        log("nextAction started for step \(step.rawValue) \(step.title)")

        if auth.isLoading {
            log("nextAction aborted because auth.isLoading == true")
            return
        }

        auth.errorMessage = nil

        if step == .basicInfo {
            var updatedDraft = draft

            if updatedDraft.businessDisplayName.trimmed.isEmpty {
                updatedDraft.businessDisplayName = updatedDraft.businessName
                log("businessDisplayName was empty -> copied from businessName")
            }

            if updatedDraft.contactPhone.trimmed.isEmpty {
                updatedDraft.contactPhone = updatedDraft.phone
                log("contactPhone was empty -> copied from phone")
            }

            if updatedDraft.legalBusinessName.trimmed.isEmpty {
                updatedDraft.legalBusinessName = updatedDraft.businessName
                log("legalBusinessName was empty -> copied from businessName")
            }

            updatedDraft.logoImageData = logoImageData
            draft = updatedDraft

            log("basicInfo step saved into draft")
            logDraftState(prefix: "after basicInfo")
        }

        if step == .publicLink {
            log("checking publicLink before continue")
            let canContinue = await auth.ensureUsernameValidForNextStep()
            log("ensureUsernameValidForNextStep -> \(canContinue)")
            log("username validation state -> \(String(describing: auth.usernameValidationState))")

            guard canContinue else {
                log("nextAction stopped on publicLink")
                return
            }
        }

        if step == .brandColor {
            log("brandColor step saved")
            log("publicCountry -> '\(draft.publicCountry)'")
            log("publicDomain -> '\(publicDomain)'")
            log("publicLanguage -> '\(draft.publicLanguage)'")
            log("publicCurrency -> '\(draft.publicCurrency)'")
            logDraftState(prefix: "after brandColor")
        }

        if step == .legalDetails {
            var updatedDraft = draft

            updatedDraft.nip = updatedDraft.nip.trimmed

            if updatedDraft.nip.isEmpty {
                log("LEGAL DETAILS: NIP is empty and this is OK — continuing without NIP")
            } else {
                log("LEGAL DETAILS: NIP provided -> '\(updatedDraft.nip)'")
            }

            if updatedDraft.complaintEmail.trimmed.isEmpty {
                updatedDraft.complaintEmail = updatedDraft.contactEmail
                log("complaintEmail was empty -> copied from contactEmail")
            }

            if updatedDraft.complaintPhone.trimmed.isEmpty {
                updatedDraft.complaintPhone = updatedDraft.contactPhone
                log("complaintPhone was empty -> copied from contactPhone")
            }

            draft = updatedDraft

            log("legalDetails step saved into draft")
            logDraftState(prefix: "after legalDetails")
        }

        if step == .firstMenu {
            var updatedDraft = draft
            updatedDraft.firstItemImageData = firstItemImageData
            draft = updatedDraft

            log("firstMenu image saved into draft -> \(firstItemImageData != nil) | bytes: \(firstItemImageData?.count ?? 0)")
            logDraftState(prefix: "after firstMenu")
        }

        if step == .finish {
            var updatedDraft = draft

            updatedDraft.logoImageData = logoImageData
            updatedDraft.firstItemImageData = firstItemImageData

            updatedDraft.nip = updatedDraft.nip.trimmed

            if updatedDraft.nip.isEmpty {
                log("FINISH: NIP is EMPTY. This should be allowed now")
            } else {
                log("FINISH: NIP is NOT empty -> '\(updatedDraft.nip)'")
            }

            if updatedDraft.complaintEmail.trimmed.isEmpty {
                updatedDraft.complaintEmail = updatedDraft.contactEmail
                log("FINISH: complaintEmail was empty -> copied contactEmail")
            }

            if updatedDraft.complaintPhone.trimmed.isEmpty {
                updatedDraft.complaintPhone = updatedDraft.contactPhone
                log("FINISH: complaintPhone was empty -> copied contactPhone")
            }

            auth.onboardingDraft = updatedDraft

            log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            log("ABOUT TO CALL auth.completeOnboarding()")
            logDraftState(prefix: "before completeOnboarding")
            log("auth.profile before complete -> \(auth.profile != nil)")
            log("auth.profile id before complete -> \(auth.profile?.id.uuidString ?? "nil")")
            log("auth.errorMessage before complete -> \(auth.errorMessage ?? "nil")")
            log("auth.noticeMessage before complete -> \(auth.noticeMessage ?? "nil")")
            log("auth.isLoading before complete -> \(auth.isLoading)")
            log("auth.onboardingStep before complete -> \(auth.onboardingStep.rawValue) \(auth.onboardingStep.title)")
            log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            await auth.completeOnboarding()

            log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            log("auth.completeOnboarding() FINISHED")
            log("auth.errorMessage after complete -> \(auth.errorMessage ?? "nil")")
            log("auth.noticeMessage after complete -> \(auth.noticeMessage ?? "nil")")
            log("auth.isLoading after complete -> \(auth.isLoading)")
            log("auth.profile exists after complete -> \(auth.profile != nil)")
            log("auth.profile id after complete -> \(auth.profile?.id.uuidString ?? "nil")")
            log("auth.onboardingStep after complete -> \(auth.onboardingStep.rawValue) \(auth.onboardingStep.title)")
            log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            if let errorMessage = auth.errorMessage, !errorMessage.isEmpty {
                log("❌ PROFILE CREATION FAILED WITH ERROR -> \(errorMessage)")
            } else if auth.profile == nil {
                log("⚠️ completeOnboarding finished without error, but auth.profile is still nil")
                log("⚠️ This usually means completeOnboarding did not refetch or assign profile")
            } else {
                log("✅ PROFILE CREATION LOOKS SUCCESSFUL")
            }
        } else {
            let nextStep = OnboardingStep(rawValue: step.rawValue + 1) ?? .finish
            log("moving to next step -> \(nextStep.rawValue) \(nextStep.title)")

            withAnimation(.easeInOut(duration: 0.22)) {
                step = nextStep
            }
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<OnboardingDraft, Value>) -> Binding<Value> {
        Binding(
            get: {
                auth.onboardingDraft[keyPath: keyPath]
            },
            set: { newValue in
                auth.onboardingDraft[keyPath: keyPath] = newValue
            }
        )
    }

    private func logValidationStateForCurrentStep() {
        switch step {
        case .basicInfo:
            log("""
            validation basicInfo:
               businessName ok -> \(draft.businessName.trimmed.count >= 2) | '\(draft.businessName)'
               address ok -> \(draft.address.trimmed.count >= 3) | '\(draft.address)'
               phone ok -> \(draft.phone.trimmed.count >= 6) | '\(draft.phone)'
            """)

        case .publicLink:
            log("""
            validation publicLink:
               username raw -> '\(draft.username)'
               username slug -> '\(draft.username.slugified)'
               username count ok -> \(draft.username.slugified.count >= 3)
               validationState -> \(String(describing: auth.usernameValidationState))
            """)

        case .brandColor:
            log("""
            validation brandColor:
               accentColorHex -> '\(draft.accentColorHex)'
               has # -> \(draft.accentColorHex.trimmed.hasPrefix("#"))
               count == 7 -> \(draft.accentColorHex.trimmed.count == 7)
               publicCountry -> '\(draft.publicCountry)'
               publicCountry valid -> \(["pl", "uk"].contains(draft.publicCountry))
               publicDomain -> '\(publicDomain)'
               publicLanguage -> '\(draft.publicLanguage)'
               publicLanguage valid -> \(["pl", "en"].contains(draft.publicLanguage))
               publicCurrency -> '\(draft.publicCurrency)'
               publicCurrency valid -> \(["PLN", "EUR", "USD", "GBP", "CAD", "UAH"].contains(draft.publicCurrency))
            """)

        case .legalDetails:
            log("""
            validation legalDetails:
               legalBusinessName ok -> \(draft.legalBusinessName.trimmed.count >= 2) | '\(draft.legalBusinessName)'
               businessDisplayName ok -> \(draft.businessDisplayName.trimmed.count >= 2) | '\(draft.businessDisplayName)'
               NIP optional -> raw: '\(draft.nip)' | trimmed: '\(draft.nip.trimmed)' | isEmpty: \(draft.nip.trimmed.isEmpty)
               addressLine1 ok -> \(draft.addressLine1.trimmed.count >= 3) | '\(draft.addressLine1)'
               postalCode ok -> \(draft.postalCode.trimmed.count >= 3) | '\(draft.postalCode)'
               city ok -> \(draft.city.trimmed.count >= 2) | '\(draft.city)'
               contactEmail ok -> \(draft.contactEmail.trimmed.contains("@")) | '\(draft.contactEmail)'
               contactPhone ok -> \(draft.contactPhone.trimmed.count >= 6) | '\(draft.contactPhone)'
            """)

        case .fulfillment:
            let hasPaymentMethod = draft.cashPaymentAvailable || draft.cardPaymentAvailable || draft.blikPaymentAvailable
            let hasFulfillment = draft.pickupAvailable || draft.deliveryAvailable
            let deliveryAreaOk = !draft.deliveryAvailable || draft.deliveryArea.trimmed.count >= 2
            let deliveryPriceOk = !draft.deliveryAvailable || Double(draft.deliveryPricePerKm.replacingOccurrences(of: ",", with: ".")) != nil

            log("""
            validation fulfillment:
               hasFulfillment -> \(hasFulfillment)
               hasPaymentMethod -> \(hasPaymentMethod)
               deliveryAvailable -> \(draft.deliveryAvailable)
               deliveryAreaOk -> \(deliveryAreaOk) | '\(draft.deliveryArea)'
               deliveryPriceOk -> \(deliveryPriceOk) | '\(draft.deliveryPricePerKm)'
            """)

        case .openingHours:
            log("""
            validation openingHours:
               hasOpenDay -> \(draft.days.contains(where: { !$0.isClosed }))
               closedDaysCount -> \(draft.days.filter { $0.isClosed }.count)
               totalDays -> \(draft.days.count)
            """)

        case .orderSettings:
            log("""
            validation orderSettings:
               slotIntervalMinutes -> \(draft.slotIntervalMinutes)
               slot valid -> \([5, 10, 15, 20, 30, 45, 60].contains(draft.slotIntervalMinutes))
            """)

        case .firstMenu:
            log("""
            validation firstMenu:
               categoryName ok -> \(draft.categoryName.trimmed.count >= 2) | '\(draft.categoryName)'
               firstItemName ok -> \(draft.firstItemName.trimmed.count >= 2) | '\(draft.firstItemName)'
               price ok -> \(Double(draft.firstItemPrice.replacingOccurrences(of: ",", with: ".")) != nil) | '\(draft.firstItemPrice)'
            """)

        case .finish:
            log("validation finish: always true")
        }
    }

    private func log(_ message: String) {
        print("🟠 [OnboardingView] \(message)")
    }

    private func logDraftState(prefix: String) {
        print("""
        🟠 [OnboardingView] \(prefix)
           step: \(step.rawValue) \(step.title)

           BASIC:
           businessName: '\(draft.businessName)'
           address: '\(draft.address)'
           phone: '\(draft.phone)'
           username: '\(draft.username)'
           usernameSlugified: '\(draft.username.slugified)'
           accentColorHex: '\(draft.accentColorHex)'
           publicCountry: '\(draft.publicCountry)'
           publicDomain: '\(publicDomain)'
           publicLanguage: '\(draft.publicLanguage)'
           publicCurrency: '\(draft.publicCurrency)'
           LEGAL:
           legalBusinessName: '\(draft.legalBusinessName)'
           businessDisplayName: '\(draft.businessDisplayName)'
           nip raw: '\(draft.nip)'
           nip trimmed: '\(draft.nip.trimmed)'
           nip isEmpty: \(draft.nip.trimmed.isEmpty)
           addressLine1: '\(draft.addressLine1)'
           addressLine2: '\(draft.addressLine2)'
           postalCode: '\(draft.postalCode)'
           city: '\(draft.city)'
           country: '\(draft.country)'
           contactEmail: '\(draft.contactEmail)'
           contactPhone: '\(draft.contactPhone)'
           complaintEmail: '\(draft.complaintEmail)'
           complaintPhone: '\(draft.complaintPhone)'

           FULFILLMENT:
           pickupAvailable: \(draft.pickupAvailable)
           deliveryAvailable: \(draft.deliveryAvailable)
           deliveryArea: '\(draft.deliveryArea)'
           deliveryPricePerKm: '\(draft.deliveryPricePerKm)'
           cashPaymentAvailable: \(draft.cashPaymentAvailable)
           cardPaymentAvailable: \(draft.cardPaymentAvailable)
           blikPaymentAvailable: \(draft.blikPaymentAvailable)

           ORDERS:
           isAcceptingOrders: \(draft.isAcceptingOrders)
           smsConfirmationEnabled: \(draft.smsConfirmationEnabled)
           slotIntervalMinutes: \(draft.slotIntervalMinutes)

           MENU:
           categoryName: '\(draft.categoryName)'
           firstItemName: '\(draft.firstItemName)'
           firstItemDescription: '\(draft.firstItemDescription)'
           firstItemPrice: '\(draft.firstItemPrice)'

           IMAGES:
           hasLogoImageData state: \(logoImageData != nil)
           logoImageData bytes state: \(logoImageData?.count ?? 0)
           hasLogoImageData draft: \(draft.logoImageData != nil)
           logoImageData bytes draft: \(draft.logoImageData?.count ?? 0)
           hasFirstItemImageData state: \(firstItemImageData != nil)
           firstItemImageData bytes state: \(firstItemImageData?.count ?? 0)
           hasFirstItemImageData draft: \(draft.firstItemImageData != nil)
           firstItemImageData bytes draft: \(draft.firstItemImageData?.count ?? 0)
        """)
    }
}

struct BasicInfoStepView: View {
    @Binding var businessName: String
    @Binding var address: String
    @Binding var phone: String
    @Binding var logoPhoto: PhotosPickerItem?
    @Binding var logoImageData: Data?

    private let accentSoft = Color(lmHex: "#5BE47B").opacity(0.14)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            LMHeroCard(
                title: OnboardingText.t("onboarding.basic.hero.title"),
                subtitle: OnboardingText.t("onboarding.basic.hero.subtitle")
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
                        Text(OnboardingText.t("onboarding.basic.info.title"))
                            .font(.wix(17, wixWeight: .semiBold))
                            .foregroundStyle(.black)

                        Text(OnboardingText.t("onboarding.basic.info.subtitle"))
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
                VStack(alignment: .leading, spacing: 16) {
                    Text(OnboardingText.t("onboarding.basic.logo.title"))
                        .font(.wix(18, wixWeight: .semiBold))
                        .foregroundStyle(.black)

                    PhotosPicker(selection: $logoPhoto, matching: .images) {
                        HStack(spacing: 16) {
                            Group {
                                if let logoImageData,
                                   let uiImage = UIImage(data: logoImageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .fill(Color.black.opacity(0.06))

                                        VStack(spacing: 8) {
                                            Image(systemName: "photo.fill")
                                                .font(.system(size: 22, weight: .semibold))
                                                .foregroundStyle(.black)

                                            Text(OnboardingText.t("onboarding.basic.logo.add"))
                                                .font(.wix(13, wixWeight: .semiBold))
                                                .foregroundStyle(.black)
                                        }
                                    }
                                }
                            }
                            .frame(width: 92, height: 92)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                            VStack(alignment: .leading, spacing: 6) {
                                Text(OnboardingText.t("onboarding.basic.logo.photo"))
                                    .font(.wix(17, wixWeight: .semiBold))
                                    .foregroundStyle(.black)

                                Text(OnboardingText.t("onboarding.basic.logo.subtitle"))
                                    .font(.wix(14, wixWeight: .regular))
                                    .foregroundStyle(.black.opacity(0.58))

                                Text(OnboardingText.t(OnboardingText.optional))
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
                    .buttonStyle(.plain)
                }
            }

            LMCard {
                VStack(spacing: 14) {
                    LMInputField(title: OnboardingText.t("onboarding.basic.field.business_name"), text: $businessName)
                    LMInputField(title: OnboardingText.t("onboarding.basic.field.address"), text: $address)
                    LMInputField(title: OnboardingText.t("onboarding.basic.field.phone"), text: $phone, keyboard: .phonePad)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct PublicLinkStepView: View {
    @Binding var username: String
    let domain: String
    let accentSoft: Color
    let validationState: AuthViewModel.UsernameValidationState
    let isBusy: Bool
    let onCheckNow: () async -> Void

    private var preview: String {
        username.slugified.isEmpty
        ? OnboardingText.t("onboarding.public_link.preview.placeholder")
        : username.slugified
    }

    private var helperText: String {
        switch validationState {
        case .idle:
            return OnboardingText.t("onboarding.public_link.helper.idle")
        case .typing:
            return OnboardingText.t("onboarding.public_link.helper.typing")
        case .checking:
            return OnboardingText.t("onboarding.public_link.helper.checking")
        case .available:
            return OnboardingText.t("onboarding.public_link.helper.available")
        case .taken:
            return OnboardingText.t("onboarding.public_link.helper.taken")
        case .invalid(let message):
            return message
        case .error(let message):
            return message
        }
    }

    private var helperColor: Color {
        switch validationState {
        case .available:
            return .green
        case .taken, .invalid, .error:
            return .red
        default:
            return .black.opacity(0.48)
        }
    }

    private var borderColor: Color {
        switch validationState {
        case .available:
            return .green.opacity(0.25)
        case .taken, .invalid, .error:
            return .red.opacity(0.25)
        default:
            return .clear
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            LMHeroCard(
                title: OnboardingText.t("onboarding.public_link.hero.title"),
                subtitle: OnboardingText.t("onboarding.public_link.hero.subtitle")
            ) {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        LMInputField(title: OnboardingText.t("onboarding.public_link.field.username"), text: $username)

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
                        Text(OnboardingText.t("onboarding.public_link.preview.title"))
                            .font(.wix(13, wixWeight: .medium))
                            .foregroundStyle(.black.opacity(0.45))

                        HStack(spacing: 10) {
                            Image(systemName: "link")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.black)

                            Text("\(domain)/\(preview)")
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
                title: OnboardingText.t("onboarding.public_link.info.title"),
                subtitle: OnboardingText.t("onboarding.public_link.info.subtitle")
            )
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .task(id: username) {
            guard !isBusy else { return }

            let normalized = username.slugified
            guard !normalized.isEmpty else { return }
            guard normalized.count >= 3 else { return }

            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            guard !isBusy else { return }

            await onCheckNow()
        }
    }
}

struct BrandColorStepView: View {
    @Binding var accentColorHex: String
    @Binding var publicCountry: String
    @Binding var publicLanguage: String
    @Binding var publicCurrency: String

    private let presets: [String] = [
        "#FFAA00",
        "#FF0043",
        "#FE592A",
        "#111111",
        "#3B82F6",
        "#8B5CF6"
    ]
    
    private let countryOptions: [CountryOption] = [
        .init(code: "pl", title: "Polska", domain: "lamenu.pl", flag: "🇵🇱"),
        .init(code: "uk", title: "United Kingdom", domain: "lamenu.uk", flag: "🇬🇧")
    ]

    private let languageOptions: [LanguageOption] = [
        .init(code: "pl", title: "Polski", subtitle: "Język strony publicznej", flag: "🇵🇱"),
        .init(code: "en", title: "English", subtitle: "Public menu language", flag: "🇬🇧")
    ]

    private let currencyOptions: [CurrencyOption] = [
        .init(code: "PLN", title: "Polski złoty", symbol: "zł", flag: "🇵🇱"),
        .init(code: "EUR", title: "Euro", symbol: "€", flag: "🇪🇺"),
        .init(code: "USD", title: "US Dollar", symbol: "$", flag: "🇺🇸"),
        .init(code: "GBP", title: "British Pound", symbol: "£", flag: "🇬🇧"),
        .init(code: "CAD", title: "Canadian Dollar", symbol: "$", flag: "🇨🇦"),
        .init(code: "UAH", title: "Ukrainian Hryvnia", symbol: "₴", flag: "🇺🇦")
    ]

    private var selectedColorBinding: Binding<Color> {
        Binding(
            get: { Color(lmHex: accentColorHex) },
            set: { newValue in
                accentColorHex = newValue.toHexString() ?? "#FFAA00"
            }
        )
    }
    
    private var selectedCountry: CountryOption {
        countryOptions.first(where: { $0.code == publicCountry }) ?? countryOptions[0]
    }

    private var selectedLanguage: LanguageOption {
        languageOptions.first(where: { $0.code == publicLanguage }) ?? languageOptions[0]
    }

    private var selectedCurrency: CurrencyOption {
        currencyOptions.first(where: { $0.code == publicCurrency }) ?? currencyOptions[0]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            LMHeroCard(
                title: OnboardingText.t("onboarding.brand.hero.title"),
                subtitle: OnboardingText.t("onboarding.brand.hero.subtitle")
            ) {
                EmptyView()
            }

            LMCard {
                VStack(alignment: .leading, spacing: 18) {
                    Text(OnboardingText.t("onboarding.brand.card.title"))
                        .font(.wix(18, wixWeight: .semiBold))
                        .foregroundStyle(.black)

                    ColorPicker(
                        OnboardingText.t("onboarding.brand.color_picker"),
                        selection: selectedColorBinding,
                        supportsOpacity: false
                    )
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
                                                ? .black
                                                : .clear,
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
                            Text(OnboardingText.t("onboarding.brand.selected.title"))
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
            
            LMCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Kraj i domena")
                        .font(.wix(18, wixWeight: .semiBold))
                        .foregroundStyle(.black)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rynek publicznej strony menu")
                            .font(.wix(13, wixWeight: .medium))
                            .foregroundStyle(.black.opacity(0.45))

                        Menu {
                            ForEach(countryOptions) { option in
                                Button {
                                    publicCountry = option.code

                                    if option.code == "uk" {
                                        publicLanguage = "en"
                                        publicCurrency = "GBP"
                                    } else {
                                        publicLanguage = "pl"
                                        publicCurrency = "PLN"
                                    }
                                } label: {
                                    Text("\(option.flag) \(option.title) — \(option.domain)")
                                }
                            }
                        } label: {
                            LMSelectRow(
                                leading: selectedCountry.flag,
                                title: selectedCountry.title,
                                subtitle: selectedCountry.domain,
                                value: selectedCountry.code.uppercased()
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            LMCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Język i waluta")
                        .font(.wix(18, wixWeight: .semiBold))
                        .foregroundStyle(.black)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Język strony menu")
                            .font(.wix(13, wixWeight: .medium))
                            .foregroundStyle(.black.opacity(0.45))

                        Menu {
                            ForEach(languageOptions) { option in
                                Button {
                                    publicLanguage = option.code
                                } label: {
                                    Text("\(option.flag) \(option.title)")
                                }
                            }
                        } label: {
                            LMSelectRow(
                                leading: selectedLanguage.flag,
                                title: selectedLanguage.title,
                                subtitle: selectedLanguage.subtitle,
                                value: selectedLanguage.code.uppercased()
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Waluta")
                            .font(.wix(13, wixWeight: .medium))
                            .foregroundStyle(.black.opacity(0.45))

                        Menu {
                            ForEach(currencyOptions) { option in
                                Button {
                                    publicCurrency = option.code
                                } label: {
                                    Text("\(option.flag) \(option.code) \(option.symbol)")
                                }
                            }
                        } label: {
                            LMSelectRow(
                                leading: selectedCurrency.flag,
                                title: selectedCurrency.title,
                                subtitle: selectedCurrency.symbol,
                                value: selectedCurrency.code
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            LMInfoCard(
                icon: "paintpalette.fill",
                title: OnboardingText.t("onboarding.brand.info.title"),
                subtitle: OnboardingText.t("onboarding.brand.info.subtitle")
            )
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct CountryOption: Identifiable {
    let code: String
    let title: String
    let domain: String
    let flag: String

    var id: String { code }
}

private struct LanguageOption: Identifiable {
    let code: String
    let title: String
    let subtitle: String
    let flag: String

    var id: String { code }
}

private struct CurrencyOption: Identifiable {
    let code: String
    let title: String
    let symbol: String
    let flag: String

    var id: String { code }
}

private struct LMSelectRow: View {
    let leading: String
    let title: String
    let subtitle: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            Text(leading)
                .font(.system(size: 28))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.wix(16, wixWeight: .semiBold))
                    .foregroundStyle(.black)

                Text(subtitle)
                    .font(.wix(13, wixWeight: .regular))
                    .foregroundStyle(.black.opacity(0.52))
            }

            Spacer()

            HStack(spacing: 8) {
                Text(value)
                    .font(.wix(14, wixWeight: .bold))
                    .foregroundStyle(.black.opacity(0.7))

                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 66)
        .background(Color.black.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct LegalDetailsStepView: View {
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
        VStack(alignment: .leading, spacing: 18) {
            LMHeroCard(
                title: OnboardingText.t("onboarding.legal.hero.title"),
                subtitle: OnboardingText.t("onboarding.legal.hero.subtitle")
            ) {
                EmptyView()
            }

            LMCard {
                VStack(spacing: 14) {
                    LMInputField(title: OnboardingText.t("onboarding.legal.field.legal_business_name"), text: $legalBusinessName)
                    LMInputField(title: OnboardingText.t("onboarding.legal.field.business_display_name"), text: $businessDisplayName)
                    LMInputField(title: OnboardingText.t("onboarding.legal.field.nip_optional"), text: $nip, keyboard: .numberPad)
                }
            }

            LMCard {
                VStack(spacing: 14) {
                    LMInputField(title: OnboardingText.t("onboarding.legal.field.address_line_1"), text: $addressLine1)
                    LMInputField(title: OnboardingText.t("onboarding.legal.field.address_line_2"), text: $addressLine2)
                    LMInputField(title: OnboardingText.t("onboarding.legal.field.postal_code"), text: $postalCode)
                    LMInputField(title: OnboardingText.t("onboarding.legal.field.city"), text: $city)
                    LMInputField(title: OnboardingText.t("onboarding.legal.field.country"), text: $country)
                }
            }

            LMCard {
                VStack(spacing: 14) {
                    LMInputField(title: OnboardingText.t("onboarding.legal.field.contact_email"), text: $contactEmail, keyboard: .emailAddress)
                    LMInputField(title: OnboardingText.t("onboarding.legal.field.contact_phone"), text: $contactPhone, keyboard: .phonePad)
                    LMInputField(title: OnboardingText.t("onboarding.legal.field.complaint_email"), text: $complaintEmail, keyboard: .emailAddress)
                    LMInputField(title: OnboardingText.t("onboarding.legal.field.complaint_phone"), text: $complaintPhone, keyboard: .phonePad)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct FulfillmentStepView: View {
    @Binding var pickupAvailable: Bool
    @Binding var deliveryAvailable: Bool
    @Binding var deliveryArea: String
    @Binding var deliveryPricePerKm: String
    @Binding var cashPaymentAvailable: Bool
    @Binding var cardPaymentAvailable: Bool
    @Binding var blikPaymentAvailable: Bool
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            LMHeroCard(
                title: OnboardingText.t("onboarding.fulfillment.hero.title"),
                subtitle: OnboardingText.t("onboarding.fulfillment.hero.subtitle")
            ) {
                EmptyView()
            }

            LMCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text(OnboardingText.t("onboarding.fulfillment.section.fulfillment"))
                        .font(.wix(18, wixWeight: .semiBold))
                        .foregroundStyle(.black)

                    LMToggleRow(
                        title: OnboardingText.t("onboarding.fulfillment.pickup.title"),
                        subtitle: OnboardingText.t("onboarding.fulfillment.pickup.subtitle"),
                        isOn: $pickupAvailable,
                        tint: accentColor
                    )

                    LMToggleRow(
                        title: OnboardingText.t("onboarding.fulfillment.delivery.title"),
                        subtitle: OnboardingText.t("onboarding.fulfillment.delivery.subtitle"),
                        isOn: $deliveryAvailable,
                        tint: accentColor
                    )

                    if deliveryAvailable {
                        LMInputField(
                            title: OnboardingText.t("onboarding.fulfillment.field.delivery_area"),
                            text: $deliveryArea
                        )

                        LMInputField(
                            title: OnboardingText.t("onboarding.fulfillment.field.delivery_price_per_km"),
                            text: $deliveryPricePerKm,
                            keyboard: .decimalPad
                        )

                        Text(OnboardingText.t("onboarding.fulfillment.delivery_price_hint"))
                            .font(.wix(13, wixWeight: .regular))
                            .foregroundStyle(.black.opacity(0.5))
                    }
                }
            }

            LMCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text(OnboardingText.t("onboarding.fulfillment.section.payment_methods"))
                        .font(.wix(18, wixWeight: .semiBold))
                        .foregroundStyle(.black)

                    LMToggleRow(
                        title: OnboardingText.t("onboarding.fulfillment.payment.cash.title"),
                        subtitle: OnboardingText.t("onboarding.fulfillment.payment.cash.subtitle"),
                        isOn: $cashPaymentAvailable,
                        tint: accentColor
                    )

                    LMToggleRow(
                        title: OnboardingText.t("onboarding.fulfillment.payment.card.title"),
                        subtitle: OnboardingText.t("onboarding.fulfillment.payment.card.subtitle"),
                        isOn: $cardPaymentAvailable,
                        tint: accentColor
                    )

                    LMToggleRow(
                        title: OnboardingText.t("onboarding.fulfillment.payment.blik.title"),
                        subtitle: OnboardingText.t("onboarding.fulfillment.payment.blik.subtitle"),
                        isOn: $blikPaymentAvailable,
                        tint: accentColor
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct OpeningHoursStepView: View {
    @Binding var days: [DayHoursDraft]
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LMHeroCard(
                title: OnboardingText.t("onboarding.opening_hours.hero.title"),
                subtitle: OnboardingText.t("onboarding.opening_hours.hero.subtitle")
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

                                Text(day.isClosed ? OnboardingText.t("onboarding.opening_hours.closed") : OnboardingText.t("onboarding.opening_hours.open"))
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
                                LMTimePickerCard(
                                    title: OnboardingText.t("onboarding.opening_hours.opening"),
                                    date: $day.openDate
                                )

                                LMTimePickerCard(
                                    title: OnboardingText.t("onboarding.opening_hours.closing"),
                                    date: $day.closeDate
                                )
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct OrderSettingsStepView: View {
    @Binding var isAcceptingOrders: Bool
    @Binding var smsConfirmationEnabled: Bool
    @Binding var slotIntervalMinutes: Int
    let accentColor: Color

    private let slotOptions = [5, 10, 15, 20, 30, 45, 60]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            LMHeroCard(
                title: OnboardingText.t("onboarding.order_settings.hero.title"),
                subtitle: OnboardingText.t("onboarding.order_settings.hero.subtitle")
            ) {
                EmptyView()
            }

            LMCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text(OnboardingText.t("onboarding.order_settings.section.status"))
                        .font(.wix(18, wixWeight: .semiBold))
                        .foregroundStyle(.black)

                    LMToggleRow(
                        title: OnboardingText.t("onboarding.order_settings.accepting_orders.title"),
                        subtitle: OnboardingText.t("onboarding.order_settings.accepting_orders.subtitle"),
                        isOn: $isAcceptingOrders,
                        tint: accentColor
                    )
                }
            }

            LMCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text(OnboardingText.t("onboarding.order_settings.section.sms"))
                        .font(.wix(18, wixWeight: .semiBold))
                        .foregroundStyle(.black)

                    LMToggleRow(
                        title: OnboardingText.t("onboarding.order_settings.sms.title"),
                        subtitle: OnboardingText.t("onboarding.order_settings.sms.subtitle"),
                        isOn: $smsConfirmationEnabled,
                        tint: accentColor
                    )
                }
            }

            LMCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text(OnboardingText.t("onboarding.order_settings.section.slots"))
                        .font(.wix(18, wixWeight: .semiBold))
                        .foregroundStyle(.black)

                    Text(OnboardingText.t("onboarding.order_settings.slot_interval"))
                        .font(.wix(13, wixWeight: .medium))
                        .foregroundStyle(.black.opacity(0.45))

                    Menu {
                        ForEach(slotOptions, id: \.self) { value in
                            Button("\(value) \(OnboardingText.t(OnboardingText.minutesShort))") {
                                slotIntervalMinutes = value
                            }
                        }
                    } label: {
                        HStack {
                            Text("\(slotIntervalMinutes) \(OnboardingText.t(OnboardingText.minutesShort))")
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
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct FirstMenuStepView: View {
    @Binding var categoryName: String
    @Binding var firstItemName: String
    @Binding var firstItemDescription: String
    @Binding var firstItemPrice: String
    @Binding var firstItemPhoto: PhotosPickerItem?
    @Binding var firstItemImageData: Data?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            LMHeroCard(
                title: OnboardingText.t("onboarding.first_menu.hero.title"),
                subtitle: OnboardingText.t("onboarding.first_menu.hero.subtitle")
            ) {
                EmptyView()
            }

            LMCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text(OnboardingText.t("onboarding.first_menu.section.category"))
                        .font(.wix(18, wixWeight: .semiBold))
                        .foregroundStyle(.black)

                    LMInputField(
                        title: OnboardingText.t("onboarding.first_menu.field.category"),
                        text: $categoryName
                    )
                }
            }

            LMCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text(OnboardingText.t("onboarding.first_menu.section.first_item"))
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

                                            Text(OnboardingText.t("onboarding.first_menu.add_photo"))
                                                .font(.wix(13, wixWeight: .semiBold))
                                                .foregroundStyle(.black)
                                        }
                                    }
                                }
                            }
                            .frame(width: 92, height: 92)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                            VStack(alignment: .leading, spacing: 6) {
                                Text(OnboardingText.t("onboarding.first_menu.item_photo"))
                                    .font(.wix(17, wixWeight: .semiBold))
                                    .foregroundStyle(.black)

                                Text(OnboardingText.t("onboarding.first_menu.item_photo_subtitle"))
                                    .font(.wix(14, wixWeight: .regular))
                                    .foregroundStyle(.black.opacity(0.58))

                                Text(OnboardingText.t(OnboardingText.optional))
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
                    .buttonStyle(.plain)

                    LMInputField(
                        title: OnboardingText.t("onboarding.first_menu.field.item_name"),
                        text: $firstItemName
                    )

                    LMInputField(
                        title: OnboardingText.t("onboarding.first_menu.field.item_description"),
                        text: $firstItemDescription
                    )

                    LMInputField(
                        title: OnboardingText.t("onboarding.first_menu.field.price"),
                        text: $firstItemPrice,
                        keyboard: .decimalPad
                    )
                }
            }

            LMInfoCard(
                icon: "sparkles",
                title: OnboardingText.t("onboarding.first_menu.info.title"),
                subtitle: OnboardingText.t("onboarding.first_menu.info.subtitle")
            )
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct FinishStepView: View {
    let draft: OnboardingDraft
    let publicDomain: String
    let logoImageData: Data?

    private var yesText: String {
        OnboardingText.t(OnboardingText.yes)
    }

    private var noText: String {
        OnboardingText.t(OnboardingText.no)
    }

    private var enabledText: String {
        OnboardingText.t(OnboardingText.enabled)
    }

    private var disabledText: String {
        OnboardingText.t(OnboardingText.disabled)
    }

    private var emptyText: String {
        OnboardingText.t(OnboardingText.emptyDash)
    }

    private var currencyText: String {
        draft.publicCurrency
    }

    private var minutesText: String {
        OnboardingText.t(OnboardingText.minutesShort)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LMHeroCard(
                title: OnboardingText.t("onboarding.finish.hero.title"),
                subtitle: OnboardingText.t("onboarding.finish.hero.subtitle")
            ) {
                EmptyView()
            }

            if let logoImageData,
               let uiImage = UIImage(data: logoImageData) {
                LMCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(OnboardingText.t("onboarding.finish.logo"))
                            .font(.wix(20, wixWeight: .bold))
                            .foregroundStyle(.black)

                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                }
            }

            summaryCard(
                title: OnboardingText.t("onboarding.finish.section.venue"),
                rows: [
                    (OnboardingText.t("onboarding.finish.row.name"), draft.businessName),
                    (OnboardingText.t("onboarding.finish.row.address"), draft.address),
                    (OnboardingText.t("onboarding.finish.row.phone"), draft.phone.trimmed.isEmpty ? emptyText : draft.phone)
                ]
            )

            summaryCard(
                title: OnboardingText.t("onboarding.finish.section.public_link"),
                rows: [
                    (OnboardingText.t("onboarding.finish.row.link"), "\(publicDomain)/\(draft.username.slugified)")
                ]
            )

            summaryCard(
                title: OnboardingText.t("onboarding.finish.section.brand_color"),
                rows: [
                    (OnboardingText.t("onboarding.finish.row.color"), draft.accentColorHex.uppercased())
                ]
            )

            summaryCard(
                title: OnboardingText.t("onboarding.finish.section.legal"),
                rows: [
                    (OnboardingText.t("onboarding.finish.row.company"), draft.legalBusinessName),
                    (OnboardingText.t("onboarding.finish.row.nip"), draft.nip.trimmed.isEmpty ? emptyText : draft.nip),
                    (OnboardingText.t("onboarding.finish.row.address"), legalAddressSummary),
                    (OnboardingText.t("onboarding.finish.row.email"), draft.contactEmail),
                    (OnboardingText.t("onboarding.finish.row.phone"), draft.contactPhone)
                ]
            )

            summaryCard(
                title: OnboardingText.t("onboarding.finish.section.fulfillment_payment"),
                rows: [
                    (OnboardingText.t("onboarding.finish.row.pickup"), draft.pickupAvailable ? yesText : noText),
                    (OnboardingText.t("onboarding.finish.row.delivery"), draft.deliveryAvailable ? yesText : noText),
                    (OnboardingText.t("onboarding.finish.row.delivery_area"), draft.deliveryAvailable ? draft.deliveryArea : emptyText),
                    (OnboardingText.t("onboarding.finish.row.delivery_price_per_km"), draft.deliveryAvailable ? "\(draft.deliveryPricePerKm) \(currencyText)" : emptyText),
                    (OnboardingText.t("onboarding.finish.row.cash"), draft.cashPaymentAvailable ? yesText : noText),
                    (OnboardingText.t("onboarding.finish.row.card"), draft.cardPaymentAvailable ? yesText : noText),
                    (OnboardingText.t("onboarding.finish.row.blik"), draft.blikPaymentAvailable ? yesText : noText)
                ]
            )

            summaryCard(
                title: OnboardingText.t("onboarding.finish.section.orders"),
                rows: [
                    (OnboardingText.t("onboarding.finish.row.status"), draft.isAcceptingOrders ? enabledText : disabledText),
                    (OnboardingText.t("onboarding.finish.row.sms"), draft.smsConfirmationEnabled ? enabledText : disabledText),
                    (OnboardingText.t("onboarding.finish.row.slots"), "\(draft.slotIntervalMinutes) \(minutesText)")
                ]
            )

            summaryCard(
                title: OnboardingText.t("onboarding.finish.section.first_menu"),
                rows: [
                    (OnboardingText.t("onboarding.finish.row.category"), draft.categoryName),
                    (OnboardingText.t("onboarding.finish.row.item"), draft.firstItemName),
                    (OnboardingText.t("onboarding.finish.row.price"), "\(draft.firstItemPrice) \(currencyText)")
                ]
            )
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
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

struct LMHeroCard<Content: View>: View {
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

struct LMCard<Content: View>: View {
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

struct LMInfoCard: View {
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

struct LMInputField: View {
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

struct LMToggleRow: View {
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

struct LMTimePickerCard: View {
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

extension Font {
    static func wix(_ size: CGFloat, wixWeight: WixWeight = .regular) -> Font {
        .custom(wixWeight.fontName, size: size)
    }
}

enum WixWeight {
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

extension String {
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

extension Color {
    init(lmHex: String) {
        let hex = lmHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64

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
