import Foundation
import Observation
import Supabase
import PostgREST
import OneSignalFramework

private struct UsernameCheckProfile: Decodable {
    let id: UUID
}

private struct ExistingNIPRecord: Decodable {
    let profile_id: UUID
    let business_display_name: String?
    let legal_business_name: String?
    let nip: String
}

private struct CreateProfilePayload: Encodable {
    let owner_user_id: String
    let business_name: String
    let username: String
    let description: String?
    let phone: String?
    let address: String?
    let logo_url: String?
    let onboarding_completed: Bool
    let is_active: Bool
    let pickup_enabled: Bool
    let delivery_enabled: Bool
    let accent_color: String
    let is_accepting_orders: Bool
    let slot_interval_minutes: Int
    let delivery_price_per_km: Double?
    let sms_confirmation_enabled: Bool
}

private struct UpdateProfilePayload: Encodable {
    let business_name: String
    let username: String
    let description: String?
    let phone: String?
    let address: String?
    let logo_url: String?
    let onboarding_completed: Bool
    let is_active: Bool
    let pickup_enabled: Bool
    let delivery_enabled: Bool
    let accent_color: String
    let is_accepting_orders: Bool
    let slot_interval_minutes: Int
    let delivery_price_per_km: Double?
    let sms_confirmation_enabled: Bool
}

private struct CreateBusinessHourPayload: Encodable {
    let profile_id: String
    let weekday: Int
    let is_closed: Bool
    let open_time: String?
    let close_time: String?
}

private struct CreateMenuPayload: Encodable {
    let profile_id: String
    let title: String
    let slug: String
    let description: String?
    let currency: String
    let is_active: Bool
    let is_public: Bool
    let sort_order: Int
}

private struct UpdateMenuPayload: Encodable {
    let title: String
    let slug: String
    let description: String?
    let currency: String
    let is_active: Bool
    let is_public: Bool
    let sort_order: Int
}

private struct CreateCategoryPayload: Encodable {
    let menu_id: String
    let name: String
    let description: String?
    let is_active: Bool
    let sort_order: Int
}

private struct CreateItemPayload: Encodable {
    let category_id: String
    let name: String
    let description: String?
    let price: Double
    let image_url: String?
    let is_available: Bool
    let sort_order: Int
}

private struct VenueLegalDetailsPayload: Encodable {
    let profile_id: String
    let legal_business_name: String
    let business_display_name: String
    let nip: String
    let address_line_1: String
    let address_line_2: String?
    let postal_code: String
    let city: String
    let country: String
    let contact_email: String
    let contact_phone: String
    let complaint_email: String
    let complaint_phone: String
    let order_hours: String?
    let delivery_area: String?
    let pickup_available: Bool
    let delivery_available: Bool
    let cash_payment_available: Bool
    let card_payment_available: Bool
    let blik_payment_available: Bool
    let terms_version: String
    let privacy_version: String
}

@MainActor
@Observable
final class AuthViewModel {
    var isAuthenticated = false
    var isLoading = true
    var errorMessage: String?
    var noticeMessage: String?

    var needsOnboarding = false
    var currentUserId: UUID?
    var profile: Profile?

    var onboardingDraft = OnboardingDraft()
    var onboardingStep: OnboardingStep = .basicInfo

    var usernameValidationState: UsernameValidationState = .idle
    private var lastCheckedUsername: String = ""

    enum UsernameValidationState: Equatable {
        case idle
        case typing
        case checking
        case available
        case taken
        case invalid(String)
        case error(String)
    }

    private let reservedUsernames: Set<String> = [
        "admin",
        "api",
        "app",
        "www",
        "panel",
        "login",
        "signup",
        "register",
        "support",
        "help",
        "regulamin",
        "polityka-prywatnosci",
        "polityka-cookies"
    ]

    func checkSession() async {
        isLoading = true
        errorMessage = nil
        noticeMessage = nil

        defer { isLoading = false }

        do {
            let session = try await SupabaseManager.shared.auth.session
            currentUserId = session.user.id
            isAuthenticated = true
            await loadProfileStatus()
        } catch {
            isAuthenticated = false
            needsOnboarding = false
            currentUserId = nil
            profile = nil
            resetOnboardingState()
        }
    }

    func signIn(email: String, password: String) async {
        guard !email.trimmed.isEmpty, !password.isEmpty else {
            errorMessage = "Wpisz e-mail i hasło."
            return
        }

        isLoading = true
        errorMessage = nil
        noticeMessage = nil

        defer { isLoading = false }

        do {
            let result = try await SupabaseManager.shared.auth.signIn(
                email: email.trimmed,
                password: password
            )

            currentUserId = result.user.id
            isAuthenticated = true
            await loadProfileStatus()
        } catch {
            errorMessage = "Nie udało się zalogować. Sprawdź dane i spróbuj ponownie."
            isAuthenticated = false
            needsOnboarding = false
        }
    }

    func signUp(email: String, password: String) async {
        guard !email.trimmed.isEmpty, !password.isEmpty else {
            errorMessage = "Wpisz e-mail i hasło."
            return
        }

        isLoading = true
        errorMessage = nil
        noticeMessage = nil

        defer { isLoading = false }

        do {
            let result = try await SupabaseManager.shared.auth.signUp(
                email: email.trimmed,
                password: password
            )

            currentUserId = result.user.id
            isAuthenticated = true
            needsOnboarding = true
            resetOnboardingState()
        } catch {
            errorMessage = "Nie udało się utworzyć konta. Spróbuj ponownie."
            isAuthenticated = false
            needsOnboarding = false
        }
    }

    func signInWithApple(
        idToken: String,
        rawNonce: String,
        givenName: String?,
        familyName: String?,
        email: String?
    ) async {
        isLoading = true
        errorMessage = nil
        noticeMessage = nil

        defer { isLoading = false }

        do {
            let result = try await SupabaseManager.shared.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: idToken,
                    nonce: rawNonce
                )
            )

            currentUserId = result.user.id
            isAuthenticated = true

            let fullName = [givenName, familyName]
                .compactMap { value in
                    guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return nil
                    }
                    return value
                }
                .joined(separator: " ")

            let metadataToSave = buildAppleMetadata(
                fullName: fullName,
                givenName: givenName,
                familyName: familyName,
                email: email
            )

            if !metadataToSave.isEmpty {
                try? await SupabaseManager.shared.auth.update(
                    user: UserAttributes(data: metadataToSave)
                )
            }

            await loadProfileStatus()
        } catch {
            errorMessage = "Nie udało się zalogować przez Apple."
            isAuthenticated = false
            needsOnboarding = false
        }
    }

    private func buildAppleMetadata(
        fullName: String,
        givenName: String?,
        familyName: String?,
        email: String?
    ) -> [String: AnyJSON] {
        var data: [String: AnyJSON] = [:]

        if !fullName.trimmed.isEmpty {
            data["full_name"] = .string(fullName.trimmed)
        }

        if let givenName, !givenName.trimmed.isEmpty {
            data["given_name"] = .string(givenName.trimmed)
        }

        if let familyName, !familyName.trimmed.isEmpty {
            data["family_name"] = .string(familyName.trimmed)
        }

        if let email, !email.trimmed.isEmpty {
            data["email"] = .string(email.trimmed)
        }

        return data
    }

    func loadProfileStatus() async {
        guard let currentUserId else {
            needsOnboarding = false
            profile = nil
            return
        }

        do {
            let profiles: [Profile] = try await SupabaseManager.shared
                .from("profiles")
                .select()
                .eq("owner_user_id", value: currentUserId.uuidString)
                .limit(1)
                .execute()
                .value

            if let existingProfile = profiles.first {
                profile = existingProfile
                needsOnboarding = !existingProfile.onboardingCompleted
                OneSignal.login(existingProfile.id.uuidString)

                if needsOnboarding {
                    await preloadOnboardingDraftIfNeeded(for: existingProfile)
                }
            } else {
                profile = nil
                needsOnboarding = true
                resetOnboardingState()
            }
        } catch {
            profile = nil
            needsOnboarding = true
        }
    }

    func updateUsernameDraft(_ rawValue: String) {
        let normalized = rawValue.slugified
        onboardingDraft.username = normalized

        errorMessage = nil
        lastCheckedUsername = ""

        if normalized.isEmpty {
            usernameValidationState = .idle
            return
        }

        if normalized.count < 3 {
            usernameValidationState = .invalid("Link musi mieć co najmniej 3 znaki.")
            return
        }

        if reservedUsernames.contains(normalized) {
            usernameValidationState = .taken
            return
        }

        usernameValidationState = .typing
    }

    func validateUsernameAvailability(force: Bool = false) async {
        let username = onboardingDraft.username.slugified
        onboardingDraft.username = username

        guard !username.isEmpty else {
            usernameValidationState = .idle
            lastCheckedUsername = ""
            return
        }

        guard username.count >= 3 else {
            usernameValidationState = .invalid("Link musi mieć co najmniej 3 znaki.")
            lastCheckedUsername = ""
            return
        }

        guard !reservedUsernames.contains(username) else {
            usernameValidationState = .taken
            lastCheckedUsername = ""
            return
        }

        if !force, lastCheckedUsername == username, usernameValidationState == .available {
            return
        }

        usernameValidationState = .checking
        errorMessage = nil

        do {
            let existingOwnedProfileId = try await fetchExistingOwnedProfileId()
            let isAvailable = try await isUsernameAvailable(username, excludingProfileId: existingOwnedProfileId)

            lastCheckedUsername = username
            usernameValidationState = isAvailable ? .available : .taken
        } catch {
            usernameValidationState = .error("Nie udało się sprawdzić linku.")
        }
    }

    func ensureUsernameValidForNextStep() async -> Bool {
        let username = onboardingDraft.username.slugified
        onboardingDraft.username = username

        await validateUsernameAvailability(force: true)

        switch usernameValidationState {
        case .available:
            return true
        case .taken:
            errorMessage = "Ten link jest już zajęty. Wybierz inny."
            return false
        case .invalid(let message):
            errorMessage = message
            return false
        case .error(let message):
            errorMessage = message
            return false
        default:
            errorMessage = "Sprawdź link publiczny jeszcze raz."
            return false
        }
    }

    func refreshNIPWarning() async {
        noticeMessage = nil

        let nip = onboardingDraft.nip.trimmed
        guard !nip.isEmpty else { return }

        do {
            let existingOwnedProfileId = try await fetchExistingOwnedProfileId()
            let existing = try await findExistingNIPUsage(nip: nip, excludingProfileId: existingOwnedProfileId)

            guard let found = existing.first else { return }

            let displayName =
                found.business_display_name?.trimmed.nilIfEmpty ??
                found.legal_business_name?.trimmed.nilIfEmpty ??
                "innym lokalu"

            noticeMessage = "Ten NIP jest już używany w lokalu „\(displayName)”. Możesz mimo to kontynuować."
        } catch {
        }
    }

    func completeOnboarding() async {
        await completeOnboarding(draft: onboardingDraft)
    }

    func completeOnboarding(draft: OnboardingDraft) async {
        guard let currentUserId else { return }
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        noticeMessage = nil

        defer { isLoading = false }

        do {
            try validateDraftForCompletion(draft)

            let username = draft.username.slugified
            let businessName = draft.businessName.trimmed
            let deliveryPricePerKmValue = Double(
                draft.deliveryPricePerKm.replacingOccurrences(of: ",", with: ".")
            )

            let existingOwnedProfileId = try await fetchExistingOwnedProfileId()
            let isAvailable = try await isUsernameAvailable(username, excludingProfileId: existingOwnedProfileId)

            guard isAvailable else {
                throw Self.makeFriendlyError("Ten link jest już zajęty. Wybierz inny.")
            }

            let existingNIPRows = try await findExistingNIPUsage(
                nip: draft.nip.trimmed,
                excludingProfileId: existingOwnedProfileId
            )

            if let found = existingNIPRows.first {
                let displayName =
                    found.business_display_name?.trimmed.nilIfEmpty ??
                    found.legal_business_name?.trimmed.nilIfEmpty ??
                    "innym lokalu"

                noticeMessage = "Ten NIP jest już używany w lokalu „\(displayName)”. Możesz mimo to kontynuować."
            }

            let profileIdForPath = existingOwnedProfileId?.uuidString ?? currentUserId.uuidString

            let uploadedLogoURL = try await uploadImageIfNeeded(
                data: draft.logoImageData,
                bucket: "logo",
                path: "profiles/\(profileIdForPath)/logo-\(UUID().uuidString).jpg"
            )

            let uploadedFirstItemImageURL = try await uploadImageIfNeeded(
                data: draft.firstItemImageData,
                bucket: "menu-items",
                path: "profiles/\(profileIdForPath)/items/first-item-\(UUID().uuidString).jpg"
            )

            let existingProfiles: [Profile] = try await SupabaseManager.shared
                .from("profiles")
                .select()
                .eq("owner_user_id", value: currentUserId.uuidString)
                .limit(1)
                .execute()
                .value

            let savedProfile: Profile

            if let existingProfile = existingProfiles.first {
                let updatePayload = UpdateProfilePayload(
                    business_name: businessName,
                    username: username,
                    description: draft.description.nilIfEmpty,
                    phone: draft.phone.nilIfEmpty,
                    address: draft.address.nilIfEmpty,
                    logo_url: uploadedLogoURL ?? existingProfile.logoURL,
                    onboarding_completed: true,
                    is_active: true,
                    pickup_enabled: draft.pickupAvailable,
                    delivery_enabled: draft.deliveryAvailable,
                    accent_color: draft.accentColorHex,
                    is_accepting_orders: draft.isAcceptingOrders,
                    slot_interval_minutes: draft.slotIntervalMinutes,
                    delivery_price_per_km: draft.deliveryAvailable ? deliveryPricePerKmValue : nil,
                    sms_confirmation_enabled: draft.smsConfirmationEnabled
                )

                savedProfile = try await SupabaseManager.shared
                    .from("profiles")
                    .update(updatePayload)
                    .eq("id", value: existingProfile.id.uuidString)
                    .select()
                    .single()
                    .execute()
                    .value

                try await SupabaseManager.shared
                    .from("business_hours")
                    .delete()
                    .eq("profile_id", value: existingProfile.id.uuidString)
                    .execute()
            } else {
                let createPayload = CreateProfilePayload(
                    owner_user_id: currentUserId.uuidString,
                    business_name: businessName,
                    username: username,
                    description: draft.description.nilIfEmpty,
                    phone: draft.phone.nilIfEmpty,
                    address: draft.address.nilIfEmpty,
                    logo_url: uploadedLogoURL,
                    onboarding_completed: true,
                    is_active: true,
                    pickup_enabled: draft.pickupAvailable,
                    delivery_enabled: draft.deliveryAvailable,
                    accent_color: draft.accentColorHex,
                    is_accepting_orders: draft.isAcceptingOrders,
                    slot_interval_minutes: draft.slotIntervalMinutes,
                    delivery_price_per_km: draft.deliveryAvailable ? deliveryPricePerKmValue : nil,
                    sms_confirmation_enabled: draft.smsConfirmationEnabled
                )

                savedProfile = try await SupabaseManager.shared
                    .from("profiles")
                    .insert(createPayload)
                    .select()
                    .single()
                    .execute()
                    .value
            }

            let profileId = savedProfile.id.uuidString

            let hoursPayload = draft.days.map { day in
                CreateBusinessHourPayload(
                    profile_id: profileId,
                    weekday: day.weekday,
                    is_closed: day.isClosed,
                    open_time: day.isClosed ? nil : day.openDate.hhmmString,
                    close_time: day.isClosed ? nil : day.closeDate.hhmmString
                )
            }

            try await SupabaseManager.shared
                .from("business_hours")
                .insert(hoursPayload)
                .execute()

            let existingMenus: [MenuRecord] = try await SupabaseManager.shared
                .from("menus")
                .select()
                .eq("profile_id", value: profileId)
                .eq("is_public", value: true)
                .limit(1)
                .execute()
                .value

            let savedMenu: MenuRecord
            let defaultMenuTitle = "Menu główne"
            let defaultMenuSlug = "\(username)-menu-glowne"

            if let existingMenu = existingMenus.first {
                let updateMenuPayload = UpdateMenuPayload(
                    title: defaultMenuTitle,
                    slug: defaultMenuSlug,
                    description: "Main public menu",
                    currency: "PLN",
                    is_active: true,
                    is_public: true,
                    sort_order: 0
                )

                savedMenu = try await SupabaseManager.shared
                    .from("menus")
                    .update(updateMenuPayload)
                    .eq("id", value: existingMenu.id.uuidString)
                    .select()
                    .single()
                    .execute()
                    .value

                try await SupabaseManager.shared
                    .from("menu_categories")
                    .delete()
                    .eq("menu_id", value: existingMenu.id.uuidString)
                    .execute()
            } else {
                let menuPayload = CreateMenuPayload(
                    profile_id: profileId,
                    title: defaultMenuTitle,
                    slug: defaultMenuSlug,
                    description: "Main public menu",
                    currency: "PLN",
                    is_active: true,
                    is_public: true,
                    sort_order: 0
                )

                savedMenu = try await SupabaseManager.shared
                    .from("menus")
                    .insert(menuPayload)
                    .select()
                    .single()
                    .execute()
                    .value
            }

            let categoryPayload = CreateCategoryPayload(
                menu_id: savedMenu.id.uuidString,
                name: draft.categoryName.trimmed,
                description: nil,
                is_active: true,
                sort_order: 0
            )

            let savedCategory: MenuCategory = try await SupabaseManager.shared
                .from("menu_categories")
                .insert(categoryPayload)
                .select()
                .single()
                .execute()
                .value

            if let price = Double(draft.firstItemPrice.replacingOccurrences(of: ",", with: ".")) {
                let itemPayload = CreateItemPayload(
                    category_id: savedCategory.id.uuidString,
                    name: draft.firstItemName.trimmed,
                    description: draft.firstItemDescription.nilIfEmpty,
                    price: price,
                    image_url: uploadedFirstItemImageURL,
                    is_available: true,
                    sort_order: 0
                )

                try await SupabaseManager.shared
                    .from("menu_items")
                    .insert(itemPayload)
                    .execute()
            }

            let legalBusinessName = draft.legalBusinessName.trimmed.isEmpty
                ? businessName
                : draft.legalBusinessName.trimmed

            let businessDisplayName = draft.businessDisplayName.trimmed.isEmpty
                ? businessName
                : draft.businessDisplayName.trimmed

            let contactEmail = draft.contactEmail.trimmed.lowercased()
            let contactPhone = draft.contactPhone.trimmed.isEmpty
                ? draft.phone.trimmed
                : draft.contactPhone.trimmed

            let complaintEmail = draft.complaintEmail.trimmed.isEmpty
                ? contactEmail
                : draft.complaintEmail.trimmed.lowercased()

            let complaintPhone = draft.complaintPhone.trimmed.isEmpty
                ? contactPhone
                : draft.complaintPhone.trimmed

            let legalPayload = VenueLegalDetailsPayload(
                profile_id: profileId,
                legal_business_name: legalBusinessName,
                business_display_name: businessDisplayName,
                nip: draft.nip.trimmed,
                address_line_1: draft.addressLine1.trimmed,
                address_line_2: draft.addressLine2.nilIfEmpty,
                postal_code: draft.postalCode.trimmed,
                city: draft.city.trimmed,
                country: draft.country.trimmed.isEmpty ? "Poland" : draft.country.trimmed,
                contact_email: contactEmail,
                contact_phone: contactPhone,
                complaint_email: complaintEmail,
                complaint_phone: complaintPhone,
                order_hours: buildOrderHoursSummary(from: draft.days),
                delivery_area: draft.deliveryAvailable ? draft.deliveryArea.nilIfEmpty : nil,
                pickup_available: draft.pickupAvailable,
                delivery_available: draft.deliveryAvailable,
                cash_payment_available: draft.cashPaymentAvailable,
                card_payment_available: draft.cardPaymentAvailable,
                blik_payment_available: draft.blikPaymentAvailable,
                terms_version: "v1",
                privacy_version: "v1"
            )

            try await SupabaseManager.shared
                .from("venue_legal_details")
                .upsert(legalPayload, onConflict: "profile_id")
                .execute()

            profile = savedProfile
            needsOnboarding = false
            OneSignal.login(savedProfile.id.uuidString)
            resetOnboardingState()
        } catch {
            errorMessage = friendlyErrorMessage(from: error)
            await loadProfileStatus()
        }
    }

    func signOut() async {
        isLoading = true
        errorMessage = nil
        noticeMessage = nil

        defer { isLoading = false }

        do {
            try await SupabaseManager.shared.auth.signOut()
            OneSignal.logout()

            isAuthenticated = false
            needsOnboarding = false
            currentUserId = nil
            profile = nil
            resetOnboardingState()
        } catch {
            errorMessage = "Nie udało się wylogować."
        }
    }

    func resetOnboardingState() {
        onboardingDraft = OnboardingDraft()
        onboardingStep = .basicInfo
        usernameValidationState = .idle
        lastCheckedUsername = ""
        errorMessage = nil
        noticeMessage = nil
    }

    private func preloadOnboardingDraftIfNeeded(for profile: Profile) async {
        guard onboardingDraft.businessName.trimmed.isEmpty else { return }

        onboardingDraft.businessName = profile.businessName
        onboardingDraft.description = profile.description ?? ""
        onboardingDraft.address = profile.address ?? ""
        onboardingDraft.phone = profile.phone ?? ""
        onboardingDraft.username = profile.username.slugified
        onboardingDraft.accentColorHex = profile.accentColor ?? "#FF0043"
        onboardingDraft.isAcceptingOrders = profile.isAcceptingOrders
        onboardingDraft.slotIntervalMinutes = profile.slotIntervalMinutes ?? 15
        onboardingDraft.smsConfirmationEnabled = profile.smsConfirmationEnabled

        if let deliveryPrice = profile.deliveryPricePerKm {
            onboardingDraft.deliveryPricePerKm = String(format: "%.2f", deliveryPrice)
                .replacingOccurrences(of: ".", with: ",")
        }

        usernameValidationState = .available
        lastCheckedUsername = profile.username.slugified
    }

    private func validateDraftForCompletion(_ draft: OnboardingDraft) throws {
        let username = draft.username.slugified

        guard draft.businessName.trimmed.count >= 2 else {
            throw Self.makeFriendlyError("Wpisz nazwę lokalu.")
        }

        guard draft.address.trimmed.count >= 3 else {
            throw Self.makeFriendlyError("Wpisz poprawny adres lokalu.")
        }

        guard draft.phone.trimmed.count >= 6 else {
            throw Self.makeFriendlyError("Wpisz poprawny numer telefonu.")
        }

        guard username.count >= 3 else {
            throw Self.makeFriendlyError("Link musi mieć co najmniej 3 znaki.")
        }

        guard !reservedUsernames.contains(username) else {
            throw Self.makeFriendlyError("Ten link nie jest dostępny. Wybierz inny.")
        }

        guard draft.accentColorHex.trimmed.hasPrefix("#"), draft.accentColorHex.trimmed.count == 7 else {
            throw Self.makeFriendlyError("Wybierz poprawny kolor firmowy.")
        }

        guard draft.legalBusinessName.trimmed.count >= 2 else {
            throw Self.makeFriendlyError("Wpisz pełną nazwę firmy.")
        }

        guard draft.businessDisplayName.trimmed.count >= 2 else {
            throw Self.makeFriendlyError("Wpisz nazwę widoczną dla klientów.")
        }

        guard draft.nip.trimmed.count >= 10 else {
            throw Self.makeFriendlyError("Wpisz poprawny NIP.")
        }

        guard draft.addressLine1.trimmed.count >= 3 else {
            throw Self.makeFriendlyError("Wpisz adres sprzedawcy.")
        }

        guard draft.postalCode.trimmed.count >= 3 else {
            throw Self.makeFriendlyError("Wpisz kod pocztowy.")
        }

        guard draft.city.trimmed.count >= 2 else {
            throw Self.makeFriendlyError("Wpisz miasto.")
        }

        guard isValidEmail(draft.contactEmail) else {
            throw Self.makeFriendlyError("Wpisz poprawny e-mail kontaktowy.")
        }

        if !draft.complaintEmail.trimmed.isEmpty {
            guard isValidEmail(draft.complaintEmail) else {
                throw Self.makeFriendlyError("Wpisz poprawny e-mail reklamacyjny.")
            }
        }

        let hasPaymentMethod = draft.cashPaymentAvailable || draft.cardPaymentAvailable || draft.blikPaymentAvailable
        guard hasPaymentMethod else {
            throw Self.makeFriendlyError("Wybierz co najmniej jedną metodę płatności.")
        }

        let hasFulfillment = draft.pickupAvailable || draft.deliveryAvailable
        guard hasFulfillment else {
            throw Self.makeFriendlyError("Włącz odbiór osobisty lub dostawę.")
        }

        if draft.deliveryAvailable {
            guard draft.deliveryArea.trimmed.count >= 2 else {
                throw Self.makeFriendlyError("Wpisz obszar dostawy.")
            }

            guard Double(draft.deliveryPricePerKm.replacingOccurrences(of: ",", with: ".")) != nil else {
                throw Self.makeFriendlyError("Wpisz poprawną cenę dostawy za 1 km.")
            }
        }

        guard draft.days.contains(where: { !$0.isClosed }) else {
            throw Self.makeFriendlyError("Ustaw co najmniej jeden aktywny dzień pracy.")
        }

        guard [5, 10, 15, 20, 30, 45, 60].contains(draft.slotIntervalMinutes) else {
            throw Self.makeFriendlyError("Wybierz poprawny odstęp slotów.")
        }

        guard draft.categoryName.trimmed.count >= 2 else {
            throw Self.makeFriendlyError("Wpisz nazwę pierwszej kategorii.")
        }

        guard draft.firstItemName.trimmed.count >= 2 else {
            throw Self.makeFriendlyError("Wpisz nazwę pierwszej pozycji.")
        }

        guard Double(draft.firstItemPrice.replacingOccurrences(of: ",", with: ".")) != nil else {
            throw Self.makeFriendlyError("Wpisz poprawną cenę pierwszej pozycji.")
        }
    }

    private func buildOrderHoursSummary(from days: [DayHoursDraft]) -> String? {
        let openDays = days.filter { !$0.isClosed }
        guard !openDays.isEmpty else { return nil }

        let parts = openDays.map { day in
            "\(day.title) \(day.openDate.hhmmString)-\(day.closeDate.hhmmString)"
        }

        return parts.joined(separator: ", ")
    }

    private func fetchExistingOwnedProfileId() async throws -> UUID? {
        guard let currentUserId else { return nil }

        let existingProfiles: [UsernameCheckProfile] = try await SupabaseManager.shared
            .from("profiles")
            .select("id")
            .eq("owner_user_id", value: currentUserId.uuidString)
            .limit(1)
            .execute()
            .value

        return existingProfiles.first?.id
    }

    private func findExistingNIPUsage(nip: String, excludingProfileId: UUID?) async throws -> [ExistingNIPRecord] {
        guard !nip.trimmed.isEmpty else { return [] }

        let rows: [ExistingNIPRecord] = try await SupabaseManager.shared
            .from("venue_legal_details")
            .select("profile_id,business_display_name,legal_business_name,nip")
            .eq("nip", value: nip.trimmed)
            .execute()
            .value

        guard let excludingProfileId else {
            return rows
        }

        return rows.filter { $0.profile_id != excludingProfileId }
    }

    private func isUsernameAvailable(_ username: String, excludingProfileId: UUID?) async throws -> Bool {
        let params: [String: AnyJSON] = [
            "check_username": .string(username.slugified),
            "exclude_profile_id": excludingProfileId.map { .string($0.uuidString) } ?? .null
        ]

        let response = try await SupabaseManager.shared
            .rpc("is_username_available", params: params)
            .execute()

        let data = response.data

        if let boolValue = try? JSONDecoder().decode(Bool.self, from: data) {
            return boolValue
        }

        if let stringValue = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() {
            if stringValue == "true" { return true }
            if stringValue == "false" { return false }
        }

        throw Self.makeFriendlyError("Nie udało się sprawdzić dostępności linku.")
    }

    private func uploadImageIfNeeded(
        data: Data?,
        bucket: String,
        path: String
    ) async throws -> String? {
        guard let data else { return nil }
        return try await SupabaseManager.uploadImage(data: data, bucket: bucket, path: path)
    }

    private func isValidEmail(_ value: String) -> Bool {
        let email = value.trimmed
        guard !email.isEmpty else { return false }

        let pattern = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    private func friendlyErrorMessage(from error: Error) -> String {
        let message = error.localizedDescription.lowercased()

        if message.contains("profiles_username_key") {
            return "Ten link jest już zajęty. Wybierz inny."
        }

        if message.contains("venue_legal_details_contact_email_check") {
            return "Wpisz poprawny e-mail kontaktowy."
        }

        if message.contains("venue_legal_details_complaint_email_check") {
            return "Wpisz poprawny e-mail reklamacyjny."
        }

        if message.contains("duplicate key value violates unique constraint") &&
            message.contains("profiles_username_key") {
            return "Ten link jest już zajęty. Wybierz inny."
        }

        if message.contains("row-level security") {
            return "Brak uprawnień do zapisania danych. Sprawdź polityki RLS w Supabase."
        }

        return error.localizedDescription
    }

    private static func makeFriendlyError(_ message: String) -> NSError {
        NSError(
            domain: "AuthViewModel",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfEmpty: String? {
        let value = trimmed
        return value.isEmpty ? nil : value
    }

    var slugified: String {
        trimmed
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .replacingOccurrences(of: "^-+|-+$", with: "", options: .regularExpression)
    }
}

private extension Date {
    var hhmmString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }
}
