import Foundation
import Observation
import Supabase
import PostgREST

@MainActor
@Observable
final class AuthViewModel {
    var isAuthenticated = false
    var isLoading = true
    var errorMessage: String?

    var needsOnboarding = false
    var currentUserId: UUID?
    var profile: Profile?

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
        }

        isLoading = false
    }

    func signIn(email: String, password: String) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Enter email and password"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await SupabaseManager.shared.auth.signIn(
                email: email,
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
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Enter email and password"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await SupabaseManager.shared.auth.signUp(
                email: email,
                password: password
            )

            currentUserId = result.user.id
            isAuthenticated = true
            needsOnboarding = true
        } catch {
            errorMessage = error.localizedDescription
            isAuthenticated = false
            needsOnboarding = false
        }

        isLoading = false
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
            } else {
                profile = nil
                needsOnboarding = true
            }
        } catch {
            profile = nil
            needsOnboarding = true
        }
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
            let is_available: Bool
            let sort_order: Int
        }

        do {
            let profilePayload = CreateProfilePayload(
                owner_user_id: currentUserId.uuidString,
                business_name: draft.businessName.trimmed,
                username: draft.username.slugified,
                description: draft.description.nilIfEmpty,
                phone: draft.phone.nilIfEmpty,
                address: draft.address.nilIfEmpty,
                onboarding_completed: true,
                is_active: true
            )

            let createdProfile: Profile = try await SupabaseManager.shared
                .from("profiles")
                .insert(profilePayload)
                .select()
                .single()
                .execute()
                .value

            let hoursPayload = draft.days.map { day in
                CreateBusinessHourPayload(
                    profile_id: createdProfile.id.uuidString,
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

            let menuSlug = "\(draft.username.slugified)-\(draft.menuTitle.slugified)"

            let menuPayload = CreateMenuPayload(
                profile_id: createdProfile.id.uuidString,
                title: draft.menuTitle.trimmed,
                slug: menuSlug,
                description: "Main public menu",
                currency: "PLN",
                is_active: true,
                is_public: true,
                sort_order: 0
            )

            let createdMenu: MenuRecord = try await SupabaseManager.shared
                .from("menus")
                .insert(menuPayload)
                .select()
                .single()
                .execute()
                .value

            let categoryPayload = CreateCategoryPayload(
                menu_id: createdMenu.id.uuidString,
                name: draft.categoryName.trimmed,
                description: nil,
                is_active: true,
                sort_order: 0
            )

            let createdCategory: MenuCategory = try await SupabaseManager.shared
                .from("menu_categories")
                .insert(categoryPayload)
                .select()
                .single()
                .execute()
                .value

            if let price = Double(draft.firstItemPrice.replacingOccurrences(of: ",", with: ".")) {
                let itemPayload = CreateItemPayload(
                    category_id: createdCategory.id.uuidString,
                    name: draft.firstItemName.trimmed,
                    description: draft.firstItemDescription.nilIfEmpty,
                    price: price,
                    is_available: true,
                    sort_order: 0
                )

                try await SupabaseManager.shared
                    .from("menu_items")
                    .insert(itemPayload)
                    .execute()
            }

            profile = createdProfile
            needsOnboarding = false
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func signOut() async {
        isLoading = true
        errorMessage = nil

        do {
            try await SupabaseManager.shared.auth.signOut()
            isAuthenticated = false
            needsOnboarding = false
            currentUserId = nil
            profile = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
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
