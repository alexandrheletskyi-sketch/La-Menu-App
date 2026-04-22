import Foundation
import Observation
import Supabase
import PostgREST

@Observable
final class EditProfileViewModel {
    enum UsernameValidationState: Equatable {
        case idle
        case typing
        case checking
        case available
        case taken
        case invalid(String)
        case error(String)
    }

    var draft = OnboardingDraft()
    var isLoading = false
    var isSaving = false
    var errorMessage: String?
    var successMessage: String?
    var usernameValidationState: UsernameValidationState = .idle

    private var profileId: UUID?
    private var currentUsername: String = ""

    private let client = SupabaseManager.shared

    func configure(profileId: UUID?) {
        self.profileId = profileId
    }

    func load() async {
        guard let profileId else { return }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        defer { isLoading = false }

        do {
            let profile = try await fetchProfile(profileId: profileId)
            let legalDetails = try await fetchLegalDetails(profileId: profileId)
            let openingHours = try await fetchOpeningHours(profileId: profileId)

            var loadedDraft = OnboardingDraft()

            loadedDraft.businessName = profile.business_name ?? ""
            loadedDraft.description = profile.description ?? ""
            loadedDraft.address = profile.address ?? ""
            loadedDraft.phone = profile.phone ?? ""
            loadedDraft.username = profile.username ?? ""
            loadedDraft.accentColorHex = profile.accent_color ?? "#5BE47B"
            loadedDraft.isAcceptingOrders = profile.is_accepting_orders ?? true
            loadedDraft.smsConfirmationEnabled = profile.sms_confirmation_enabled ?? true
            loadedDraft.pickupAvailable = profile.pickup_enabled ?? true
            loadedDraft.deliveryAvailable = profile.delivery_enabled ?? false
            loadedDraft.slotIntervalMinutes = profile.slot_interval_minutes ?? 15
            loadedDraft.deliveryPricePerKm = profile.delivery_price_per_km.map {
                Self.decimalString(from: $0)
            } ?? ""

            if let legalDetails {
                loadedDraft.legalBusinessName = legalDetails.legal_business_name ?? ""
                loadedDraft.businessDisplayName = legalDetails.business_display_name ?? (profile.business_name ?? "")
                loadedDraft.nip = legalDetails.nip ?? ""
                loadedDraft.addressLine1 = legalDetails.address_line_1 ?? ""
                loadedDraft.addressLine2 = legalDetails.address_line_2 ?? ""
                loadedDraft.postalCode = legalDetails.postal_code ?? ""
                loadedDraft.city = legalDetails.city ?? ""
                loadedDraft.country = legalDetails.country ?? "Poland"
                loadedDraft.contactEmail = legalDetails.contact_email ?? ""
                loadedDraft.contactPhone = legalDetails.contact_phone ?? (profile.phone ?? "")
                loadedDraft.complaintEmail = legalDetails.complaint_email ?? ""
                loadedDraft.complaintPhone = legalDetails.complaint_phone ?? ""
                loadedDraft.deliveryArea = legalDetails.delivery_area ?? ""

                loadedDraft.pickupAvailable = legalDetails.pickup_available ?? loadedDraft.pickupAvailable
                loadedDraft.deliveryAvailable = legalDetails.delivery_available ?? loadedDraft.deliveryAvailable
                loadedDraft.cashPaymentAvailable = legalDetails.cash_payment_available ?? true
                loadedDraft.cardPaymentAvailable = legalDetails.card_payment_available ?? false
                loadedDraft.blikPaymentAvailable = legalDetails.blik_payment_available ?? false
            }

            applyOpeningHoursRows(openingHours, to: &loadedDraft)

            draft = loadedDraft
            currentUsername = loadedDraft.username.slugified
            usernameValidationState = currentUsername.count >= 3 ? .available : .idle
        } catch {
            errorMessage = "Nie udało się wczytać danych profilu: \(error.localizedDescription)"
        }
    }

    func save() async {
        guard let profileId else { return }
        guard validateAll() else { return }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        defer { isSaving = false }

        do {
            if draft.username.slugified != currentUsername {
                let usernameOk = await ensureUsernameStillAvailable()
                guard usernameOk else { return }
            }

            try await updateProfile(profileId: profileId)
            try await upsertLegalDetails(profileId: profileId)
            try await replaceOpeningHours(profileId: profileId)

            currentUsername = draft.username.slugified
            successMessage = "Zmiany zostały zapisane"
        } catch {
            errorMessage = "Nie udało się zapisać zmian: \(error.localizedDescription)"
        }
    }

    func usernameDidChange() {
        successMessage = nil

        let normalized = draft.username.slugified
        if normalized.isEmpty {
            usernameValidationState = .idle
            return
        }

        if normalized.count < 3 {
            usernameValidationState = .invalid("Link musi mieć co najmniej 3 znaki")
            return
        }

        usernameValidationState = .typing
    }

    func validateUsernameAvailability() async {
        let normalized = draft.username.slugified

        guard !normalized.isEmpty else {
            usernameValidationState = .idle
            return
        }

        guard normalized.count >= 3 else {
            usernameValidationState = .invalid("Link musi mieć co najmniej 3 znaki")
            return
        }

        if normalized == currentUsername {
            usernameValidationState = .available
            return
        }

        usernameValidationState = .checking

        do {
            let matches: [UsernameLookupRow] = try await client
                .from("profiles")
                .select("id, username")
                .eq("username", value: normalized)
                .neq("id", value: profileId?.uuidString ?? "")
                .limit(1)
                .execute()
                .value

            usernameValidationState = matches.isEmpty ? .available : .taken
        } catch {
            usernameValidationState = .error("Nie udało się sprawdzić linku")
        }
    }

    func ensureUsernameStillAvailable() async -> Bool {
        await validateUsernameAvailability()

        switch usernameValidationState {
        case .available:
            return true
        case .taken:
            errorMessage = "Ten link jest już zajęty"
            return false
        case .invalid(let message):
            errorMessage = message
            return false
        case .error(let message):
            errorMessage = message
            return false
        default:
            errorMessage = "Sprawdź poprawność linku"
            return false
        }
    }

    var canSave: Bool {
        basicInfoValid &&
        brandColorValid &&
        legalDetailsValid &&
        fulfillmentValid &&
        openingHoursValid &&
        orderSettingsValid
    }

    private var basicInfoValid: Bool {
        draft.businessName.trimmed.count >= 2 &&
        draft.address.trimmed.count >= 3 &&
        draft.phone.trimmed.count >= 6
    }

    private var brandColorValid: Bool {
        draft.accentColorHex.trimmed.hasPrefix("#") &&
        draft.accentColorHex.trimmed.count == 7
    }

    private var legalDetailsValid: Bool {
        draft.legalBusinessName.trimmed.count >= 2 &&
        draft.businessDisplayName.trimmed.count >= 2 &&
        draft.nip.trimmed.count >= 10 &&
        draft.addressLine1.trimmed.count >= 3 &&
        draft.postalCode.trimmed.count >= 3 &&
        draft.city.trimmed.count >= 2 &&
        draft.contactEmail.trimmed.contains("@") &&
        draft.contactPhone.trimmed.count >= 6
    }

    private var fulfillmentValid: Bool {
        let hasPaymentMethod = draft.cashPaymentAvailable || draft.cardPaymentAvailable || draft.blikPaymentAvailable
        let hasFulfillment = draft.pickupAvailable || draft.deliveryAvailable
        let deliveryAreaOk = !draft.deliveryAvailable || draft.deliveryArea.trimmed.count >= 2
        let deliveryPriceOk = !draft.deliveryAvailable || Double(draft.deliveryPricePerKm.replacingOccurrences(of: ",", with: ".")) != nil

        return hasFulfillment && hasPaymentMethod && deliveryAreaOk && deliveryPriceOk
    }

    private var openingHoursValid: Bool {
        draft.days.contains(where: { !$0.isClosed })
    }

    private var orderSettingsValid: Bool {
        [5, 10, 15, 20, 30, 45, 60].contains(draft.slotIntervalMinutes)
    }

    private func validateAll() -> Bool {
        if !basicInfoValid {
            errorMessage = "Uzupełnij podstawowe dane lokalu"
            return false
        }

        if !brandColorValid {
            errorMessage = "Sprawdź kolor marki"
            return false
        }

        if !legalDetailsValid {
            errorMessage = "Uzupełnij poprawnie dane prawne"
            return false
        }

        if !fulfillmentValid {
            errorMessage = "Sprawdź ustawienia dostawy i płatności"
            return false
        }

        if !openingHoursValid {
            errorMessage = "Włącz przynajmniej jeden dzień otwarcia"
            return false
        }

        if !orderSettingsValid {
            errorMessage = "Wybierz poprawny odstęp między slotami"
            return false
        }

        return true
    }
}

// MARK: - Fetch

private extension EditProfileViewModel {
    func fetchProfile(profileId: UUID) async throws -> ProfileRow {
        try await client
            .from("profiles")
            .select("""
                id,
                business_name,
                username,
                description,
                phone,
                address,
                is_active,
                pickup_enabled,
                delivery_enabled,
                accent_color,
                is_accepting_orders,
                slot_interval_minutes,
                delivery_price_per_km,
                sms_confirmation_enabled
            """)
            .eq("id", value: profileId.uuidString)
            .single()
            .execute()
            .value
    }

    func fetchLegalDetails(profileId: UUID) async throws -> VenueLegalDetailsRow? {
        let rows: [VenueLegalDetailsRow] = try await client
            .from("venue_legal_details")
            .select("""
                profile_id,
                legal_business_name,
                business_display_name,
                address_line_1,
                address_line_2,
                postal_code,
                city,
                country,
                nip,
                contact_email,
                contact_phone,
                complaint_email,
                complaint_phone,
                delivery_area,
                order_hours,
                pickup_available,
                delivery_available,
                cash_payment_available,
                card_payment_available,
                blik_payment_available,
                terms_version,
                privacy_version
            """)
            .eq("profile_id", value: profileId.uuidString)
            .limit(1)
            .execute()
            .value

        return rows.first
    }

    func fetchOpeningHours(profileId: UUID) async throws -> [BusinessHourRow] {
        try await client
            .from("business_hours")
            .select("""
                profile_id,
                weekday,
                is_closed,
                open_time,
                close_time
            """)
            .eq("profile_id", value: profileId.uuidString)
            .order("weekday", ascending: true)
            .execute()
            .value
    }
}

// MARK: - Save

private extension EditProfileViewModel {
    func updateProfile(profileId: UUID) async throws {
        let payload = ProfileUpdatePayload(
            business_name: draft.businessName.trimmed,
            username: draft.username.slugified,
            description: draft.description.trimmed.nilIfEmpty,
            phone: draft.phone.trimmed.nilIfEmpty,
            address: draft.address.trimmed.nilIfEmpty,
            pickup_enabled: draft.pickupAvailable,
            delivery_enabled: draft.deliveryAvailable,
            accent_color: draft.accentColorHex.uppercased(),
            is_accepting_orders: draft.isAcceptingOrders,
            slot_interval_minutes: draft.slotIntervalMinutes,
            delivery_price_per_km: draft.deliveryAvailable ? Self.decimalFromString(draft.deliveryPricePerKm) : nil,
            sms_confirmation_enabled: draft.smsConfirmationEnabled
        )

        try await client
            .from("profiles")
            .update(payload)
            .eq("id", value: profileId.uuidString)
            .execute()
    }

    func upsertLegalDetails(profileId: UUID) async throws {
        let payload = VenueLegalDetailsUpsertPayload(
            profile_id: profileId,
            legal_business_name: draft.legalBusinessName.trimmed,
            business_display_name: draft.businessDisplayName.trimmed,
            address_line_1: draft.addressLine1.trimmed,
            address_line_2: draft.addressLine2.trimmed.nilIfEmpty,
            postal_code: draft.postalCode.trimmed,
            city: draft.city.trimmed,
            country: draft.country.trimmed.isEmpty ? "Poland" : draft.country.trimmed,
            nip: draft.nip.trimmed,
            contact_email: draft.contactEmail.trimmed,
            contact_phone: draft.contactPhone.trimmed,
            complaint_email: draft.complaintEmail.trimmed.nilIfEmpty,
            complaint_phone: draft.complaintPhone.trimmed.nilIfEmpty,
            delivery_area: draft.deliveryAvailable ? draft.deliveryArea.trimmed.nilIfEmpty : nil,
            order_hours: buildOrderHoursSummary(from: draft.days),
            pickup_available: draft.pickupAvailable,
            delivery_available: draft.deliveryAvailable,
            cash_payment_available: draft.cashPaymentAvailable,
            card_payment_available: draft.cardPaymentAvailable,
            blik_payment_available: draft.blikPaymentAvailable,
            terms_version: "v1",
            privacy_version: "v1"
        )

        try await client
            .from("venue_legal_details")
            .upsert(payload, onConflict: "profile_id")
            .execute()
    }

    func replaceOpeningHours(profileId: UUID) async throws {
        try await client
            .from("business_hours")
            .delete()
            .eq("profile_id", value: profileId.uuidString)
            .execute()

        let rows: [BusinessHourInsertPayload] = draft.days.map { day in
            BusinessHourInsertPayload(
                profile_id: profileId,
                weekday: day.weekday,
                is_closed: day.isClosed,
                open_time: day.isClosed ? nil : Self.hhmmString(from: day.openDate),
                close_time: day.isClosed ? nil : Self.hhmmString(from: day.closeDate)
            )
        }

        guard !rows.isEmpty else { return }

        try await client
            .from("business_hours")
            .insert(rows)
            .execute()
    }

    func buildOrderHoursSummary(from days: [DayHoursDraft]) -> String? {
        let openDays = days.filter { !$0.isClosed }
        guard !openDays.isEmpty else { return nil }

        let parts = openDays.map { day in
            "\(day.title) \(Self.hhmmString(from: day.openDate))-\(Self.hhmmString(from: day.closeDate))"
        }

        return parts.joined(separator: ", ")
    }
}

// MARK: - Mapping

private extension EditProfileViewModel {
    func applyOpeningHoursRows(_ rows: [BusinessHourRow], to draft: inout OnboardingDraft) {
        let weekdayToIndex: [Int: Int] = [
            1: 0,
            2: 1,
            3: 2,
            4: 3,
            5: 4,
            6: 5,
            7: 6
        ]

        for row in rows {
            guard let index = weekdayToIndex[row.weekday] else { continue }
            guard draft.days.indices.contains(index) else { continue }

            draft.days[index].isClosed = row.is_closed

            if let openTime = row.open_time,
               let parsedOpenDate = Self.dateFromHHMM(openTime) {
                draft.days[index].openDate = parsedOpenDate
            }

            if let closeTime = row.close_time,
               let parsedCloseDate = Self.dateFromHHMM(closeTime) {
                draft.days[index].closeDate = parsedCloseDate
            }
        }
    }

    static func dateFromHHMM(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"

        if let date = formatter.date(from: value) {
            return date
        }

        formatter.dateFormat = "HH:mm:ss"
        return formatter.date(from: value)
    }

    static func hhmmString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    static func decimalString(from value: Double) -> String {
        let string = String(format: "%.2f", value)
        return string.replacingOccurrences(of: ".", with: ",")
    }

    static func decimalFromString(_ value: String) -> Double? {
        Double(value.replacingOccurrences(of: ",", with: "."))
    }
}

// MARK: - DTOs

private struct ProfileRow: Decodable {
    let id: UUID
    let business_name: String?
    let username: String?
    let description: String?
    let phone: String?
    let address: String?
    let is_active: Bool?
    let pickup_enabled: Bool?
    let delivery_enabled: Bool?
    let accent_color: String?
    let is_accepting_orders: Bool?
    let slot_interval_minutes: Int?
    let delivery_price_per_km: Double?
    let sms_confirmation_enabled: Bool?
}

private struct VenueLegalDetailsRow: Decodable {
    let profile_id: UUID
    let legal_business_name: String?
    let business_display_name: String?
    let address_line_1: String?
    let address_line_2: String?
    let postal_code: String?
    let city: String?
    let country: String?
    let nip: String?
    let contact_email: String?
    let contact_phone: String?
    let complaint_email: String?
    let complaint_phone: String?
    let delivery_area: String?
    let order_hours: String?
    let pickup_available: Bool?
    let delivery_available: Bool?
    let cash_payment_available: Bool?
    let card_payment_available: Bool?
    let blik_payment_available: Bool?
    let terms_version: String?
    let privacy_version: String?
}

private struct BusinessHourRow: Decodable {
    let profile_id: UUID
    let weekday: Int
    let is_closed: Bool
    let open_time: String?
    let close_time: String?
}

private struct UsernameLookupRow: Decodable {
    let id: UUID
    let username: String?
}

private struct ProfileUpdatePayload: Encodable {
    let business_name: String
    let username: String
    let description: String?
    let phone: String?
    let address: String?
    let pickup_enabled: Bool
    let delivery_enabled: Bool
    let accent_color: String
    let is_accepting_orders: Bool
    let slot_interval_minutes: Int
    let delivery_price_per_km: Double?
    let sms_confirmation_enabled: Bool
}

private struct VenueLegalDetailsUpsertPayload: Encodable {
    let profile_id: UUID
    let legal_business_name: String
    let business_display_name: String
    let address_line_1: String
    let address_line_2: String?
    let postal_code: String
    let city: String
    let country: String
    let nip: String
    let contact_email: String
    let contact_phone: String
    let complaint_email: String?
    let complaint_phone: String?
    let delivery_area: String?
    let order_hours: String?
    let pickup_available: Bool
    let delivery_available: Bool
    let cash_payment_available: Bool
    let card_payment_available: Bool
    let blik_payment_available: Bool
    let terms_version: String
    let privacy_version: String
}

private struct BusinessHourInsertPayload: Encodable {
    let profile_id: UUID
    let weekday: Int
    let is_closed: Bool
    let open_time: String?
    let close_time: String?
}

// MARK: - Helpers

private extension String {
    var nilIfEmpty: String? {
        trimmed.isEmpty ? nil : trimmed
    }
}
