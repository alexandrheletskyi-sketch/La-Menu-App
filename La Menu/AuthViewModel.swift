import Foundation
import Observation
import Supabase
import PostgREST
import OneSignalFramework

@MainActor
@Observable
final class AuthViewModel {
    var isAuthenticated = false
    var isLoading = true
    var errorMessage: String?

    var needsOnboarding = false
    var currentUserId: UUID?
    var profile: Profile?

    var onboardingDraft = OnboardingDraft()
    var onboardingStep: OnboardingStep = .basicInfo

    // MARK: - Session

    func checkSession() async {
        isLoading = true
        errorMessage = nil

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

        isLoading = false
    }

    // MARK: - Email / Password

    func signIn(email: String, password: String) async {
        guard !email.trimmed.isEmpty, !password.isEmpty else {
            errorMessage = "Enter email and password"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await SupabaseManager.shared.auth.signIn(
                email: email.trimmed,
                password: password
            )

            currentUserId = result.user.id
            isAuthenticated = true
            await loadProfileStatus()
        } catch {
            errorMessage = error.localizedDescription
            isAuthenticated = false
            needsOnboarding = false
        }

        isLoading = false
    }

    func signUp(email: String, password: String) async {
        guard !email.trimmed.isEmpty, !password.isEmpty else {
            errorMessage = "Enter email and password"
            return
        }

        isLoading = true
        errorMessage = nil

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
            errorMessage = error.localizedDescription
            isAuthenticated = false
            needsOnboarding = false
        }

        isLoading = false
    }

    // MARK: - Apple Sign In

    func signInWithApple(
        idToken: String,
        rawNonce: String,
        givenName: String?,
        familyName: String?,
        email: String?
    ) async {
        isLoading = true
        errorMessage = nil

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
            errorMessage = error.localizedDescription
            isAuthenticated = false
            needsOnboarding = false
        }

        isLoading = false
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

    // MARK: - Profile

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

    // MARK: - Onboarding

    func completeOnboarding() async {
        await completeOnboarding(draft: onboardingDraft)
    }

    func completeOnboarding(draft: OnboardingDraft) async {
        guard let currentUserId else { return }

        isLoading = true
        errorMessage = nil

        struct CreateProfilePayload: Encodable {
            let owner_user_id: String
            let business_name: String
            let username: String
            let description: String?
            let phone: String?
            let address: String?
            let logo_url: String?
            let onboarding_completed: Bool
            let is_active: Bool
        }

        struct UpdateProfilePayload: Encodable {
            let business_name: String
            let username: String
            let description: String?
            let phone: String?
            let address: String?
            let logo_url: String?
            let onboarding_completed: Bool
            let is_active: Bool
        }

        struct CreateBusinessHourPayload: Encodable {
            let profile_id: String
            let weekday: Int
            let is_closed: Bool
            let open_time: String?
            let close_time: String?
        }

        struct CreateMenuPayload: Encodable {
            let profile_id: String
            let title: String
            let slug: String
            let description: String?
            let currency: String
            let is_active: Bool
            let is_public: Bool
            let sort_order: Int
        }

        struct UpdateMenuPayload: Encodable {
            let title: String
            let slug: String
            let description: String?
            let currency: String
            let is_active: Bool
            let is_public: Bool
            let sort_order: Int
        }

        struct CreateCategoryPayload: Encodable {
            let menu_id: String
            let name: String
            let description: String?
            let is_active: Bool
            let sort_order: Int
        }

        struct CreateItemPayload: Encodable {
            let category_id: String
            let name: String
            let description: String?
            let price: Double
            let image_url: String?
            let is_available: Bool
            let sort_order: Int
        }

        struct VenueLegalDetailsPayload: Encodable {
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

        do {
            let username = draft.username.slugified
            let businessName = draft.businessName.trimmed

            if username.count < 3 {
                throw AuthViewModel.makeFriendlyError("Link musi mieć co najmniej 3 znaki.")
            }

            let existingProfiles: [Profile] = try await SupabaseManager.shared
                .from("profiles")
                .select()
                .eq("owner_user_id", value: currentUserId.uuidString)
                .limit(1)
                .execute()
                .value

            let existingOwnedProfileId = existingProfiles.first?.id
            try await validateUsernameAvailability(username, excludingProfileId: existingOwnedProfileId)

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
                    is_active: true
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
                    is_active: true
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

            let contactEmail = draft.contactEmail.trimmed
            let contactPhone = draft.contactPhone.trimmed.isEmpty
                ? draft.phone.trimmed
                : draft.contactPhone.trimmed

            let complaintEmail = draft.complaintEmail.trimmed.isEmpty
                ? contactEmail
                : draft.complaintEmail.trimmed

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
        }

        isLoading = false
    }

    // MARK: - Sign out

    func signOut() async {
        isLoading = true
        errorMessage = nil

        do {
            try await SupabaseManager.shared.auth.signOut()
            OneSignal.logout()

            isAuthenticated = false
            needsOnboarding = false
            currentUserId = nil
            profile = nil
            resetOnboardingState()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Helpers

    func resetOnboardingState() {
        onboardingDraft = OnboardingDraft()
        onboardingStep = .basicInfo
    }

    private func preloadOnboardingDraftIfNeeded(for profile: Profile) async {
        guard onboardingDraft.businessName.trimmed.isEmpty else { return }

        onboardingDraft.businessName = profile.businessName
        onboardingDraft.description = profile.description ?? ""
        onboardingDraft.address = profile.address ?? ""
        onboardingDraft.phone = profile.phone ?? ""
        onboardingDraft.username = profile.username
    }

    private func buildOrderHoursSummary(from days: [DayHoursDraft]) -> String? {
        let openDays = days.filter { !$0.isClosed }
        guard !openDays.isEmpty else { return nil }

        let parts = openDays.map { day in
            "\(day.title) \(day.openDate.hhmmString)-\(day.closeDate.hhmmString)"
        }

        return parts.joined(separator: ", ")
    }

    private struct UsernameCheckProfile: Decodable {
        let id: UUID
    }

    private func validateUsernameAvailability(_ username: String, excludingProfileId: UUID?) async throws {
        let existing: [UsernameCheckProfile] = try await SupabaseManager.shared
            .from("profiles")
            .select("id")
            .eq("username", value: username)
            .execute()
            .value

        if let excludingProfileId {
            let takenByAnotherProfile = existing.contains { $0.id != excludingProfileId }
            if takenByAnotherProfile {
                throw AuthViewModel.makeFriendlyError("Ten link jest już zajęty. Wybierz inny.")
            }
        } else if !existing.isEmpty {
            throw AuthViewModel.makeFriendlyError("Ten link jest już zajęty. Wybierz inny.")
        }
    }

    private func uploadImageIfNeeded(
        data: Data?,
        bucket: String,
        path: String
    ) async throws -> String? {
        guard let data else { return nil }
        return try await SupabaseManager.uploadImage(data: data, bucket: bucket, path: path)
    }

    private func friendlyErrorMessage(from error: Error) -> String {
        let message = error.localizedDescription

        if message.localizedCaseInsensitiveContains("profiles_username_key") ||
            message.localizedCaseInsensitiveContains("duplicate key value violates unique constraint") {
            return "Ten link jest już zajęty. Wybierz inny."
        }

        return message
    }

    private static func makeFriendlyError(_ message: String) -> NSError {
        NSError(
            domain: "AuthViewModel",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}

// MARK: - Extensions

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
