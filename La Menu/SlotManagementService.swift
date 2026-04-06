import Foundation
import Supabase
import PostgREST

private struct VenueSlotSettingsInsertPayload: Encodable, Sendable {
    let profile_id: UUID
    let slots_enabled: Bool
    let slot_duration_minutes: Int
    let default_capacity: Int
    let days_ahead: Int
    let lead_time_minutes: Int
    let allow_asap: Bool
}

private struct VenueSlotSettingsUpdatePayload: Encodable, Sendable {
    let slots_enabled: Bool
    let slot_duration_minutes: Int
    let default_capacity: Int
    let days_ahead: Int
    let lead_time_minutes: Int
    let allow_asap: Bool
}

private struct SlotDateOverrideUpsertPayload: Encodable, Sendable {
    let profile_id: UUID
    let override_date: String
    let fulfillment_type: String
    let is_closed: Bool
    let open_time: String?
    let close_time: String?
    let capacity_override: Int?
    let note: String?
}

private struct SlotOverrideUpsertPayload: Encodable, Sendable {
    let profile_id: UUID
    let fulfillment_type: String
    let slot_start: String
    let slot_end: String
    let is_blocked: Bool
    let capacity_override: Int?
    let note: String?
}

struct SlotManagementService {
    private let client = SupabaseManager.shared

    func fetchSettings(profileId: UUID) async throws -> VenueSlotSettings {
        do {
            return try await client
                .from("venue_slot_settings")
                .select()
                .eq("profile_id", value: profileId.uuidString)
                .single()
                .execute()
                .value
        } catch {
            let fallback = VenueSlotSettings.placeholder(profileId: profileId)

            let payload = VenueSlotSettingsInsertPayload(
                profile_id: profileId,
                slots_enabled: fallback.slotsEnabled,
                slot_duration_minutes: fallback.slotDurationMinutes,
                default_capacity: fallback.defaultCapacity,
                days_ahead: fallback.daysAhead,
                lead_time_minutes: fallback.leadTimeMinutes,
                allow_asap: fallback.allowAsap
            )

            try await client
                .from("venue_slot_settings")
                .insert(payload)
                .execute()

            return try await client
                .from("venue_slot_settings")
                .select()
                .eq("profile_id", value: profileId.uuidString)
                .single()
                .execute()
                .value
        }
    }

    func updateSettings(_ settings: VenueSlotSettings) async throws {
        let payload = VenueSlotSettingsUpdatePayload(
            slots_enabled: settings.slotsEnabled,
            slot_duration_minutes: settings.slotDurationMinutes,
            default_capacity: settings.defaultCapacity,
            days_ahead: settings.daysAhead,
            lead_time_minutes: settings.leadTimeMinutes,
            allow_asap: settings.allowAsap
        )

        try await client
            .from("venue_slot_settings")
            .update(payload)
            .eq("profile_id", value: settings.profileId.uuidString)
            .execute()
    }

    func fetchAvailableSlots(
        profileId: UUID,
        date: Date,
        fulfillmentType: SlotFulfillmentType,
        timezone: String = "Europe/Warsaw"
    ) async throws -> [AvailableSlot] {
        let params: [String: String] = [
            "p_profile_id": profileId.uuidString,
            "p_target_date": DateFormatter.yyyyMMdd.string(from: date),
            "p_fulfillment_type": fulfillmentType.rawValue,
            "p_timezone": timezone
        ]

        return try await client
            .rpc("get_available_slots", params: params)
            .execute()
            .value
    }

    func fetchAdminDaySlots(
        profileId: UUID,
        date: Date,
        fulfillmentType: SlotFulfillmentType,
        timezone: String = "Europe/Warsaw"
    ) async throws -> [AdminDaySlot] {
        let params: [String: String] = [
            "p_profile_id": profileId.uuidString,
            "p_target_date": DateFormatter.yyyyMMdd.string(from: date),
            "p_fulfillment_type": fulfillmentType.rawValue,
            "p_timezone": timezone
        ]

        return try await client
            .rpc("get_day_slots_for_admin", params: params)
            .execute()
            .value
    }

    func fetchDateOverride(
        profileId: UUID,
        date: Date,
        fulfillmentType: SlotFulfillmentType
    ) async throws -> SlotDateOverride? {
        let items: [SlotDateOverride] = try await client
            .from("venue_slot_date_overrides")
            .select()
            .eq("profile_id", value: profileId.uuidString)
            .eq("override_date", value: DateFormatter.yyyyMMdd.string(from: date))
            .eq("fulfillment_type", value: fulfillmentType.rawValue)
            .limit(1)
            .execute()
            .value

        return items.first
    }

    func upsertDateOverride(
        profileId: UUID,
        date: Date,
        fulfillmentType: SlotFulfillmentType,
        draft: SlotDateOverrideDraft
    ) async throws {
        let trimmedNote = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)

        let payload = SlotDateOverrideUpsertPayload(
            profile_id: profileId,
            override_date: DateFormatter.yyyyMMdd.string(from: date),
            fulfillment_type: fulfillmentType.rawValue,
            is_closed: draft.isClosed,
            open_time: draft.isClosed ? nil : DateFormatter.hm24.string(from: draft.openDate),
            close_time: draft.isClosed ? nil : DateFormatter.hm24.string(from: draft.closeDate),
            capacity_override: Int(draft.capacityOverride),
            note: trimmedNote.isEmpty ? nil : trimmedNote
        )

        try await client
            .from("venue_slot_date_overrides")
            .upsert(payload, onConflict: "profile_id,override_date,fulfillment_type")
            .execute()
    }

    func deleteDateOverride(
        profileId: UUID,
        date: Date,
        fulfillmentType: SlotFulfillmentType
    ) async throws {
        try await client
            .from("venue_slot_date_overrides")
            .delete()
            .eq("profile_id", value: profileId.uuidString)
            .eq("override_date", value: DateFormatter.yyyyMMdd.string(from: date))
            .eq("fulfillment_type", value: fulfillmentType.rawValue)
            .execute()
    }

    func fetchSlotOverride(
        profileId: UUID,
        slotStartISO: String,
        fulfillmentType: SlotFulfillmentType
    ) async throws -> SlotOverride? {
        let items: [SlotOverride] = try await client
            .from("venue_slot_overrides")
            .select()
            .eq("profile_id", value: profileId.uuidString)
            .eq("slot_start", value: slotStartISO)
            .eq("fulfillment_type", value: fulfillmentType.rawValue)
            .limit(1)
            .execute()
            .value

        return items.first
    }

    func setSlotBlocked(
        profileId: UUID,
        fulfillmentType: SlotFulfillmentType,
        slot: AvailableSlot,
        blocked: Bool
    ) async throws {
        if blocked {
            let existing = try await fetchSlotOverride(
                profileId: profileId,
                slotStartISO: slot.slotStartRaw,
                fulfillmentType: fulfillmentType
            )

            let payload = SlotOverrideUpsertPayload(
                profile_id: profileId,
                fulfillment_type: fulfillmentType.rawValue,
                slot_start: slot.slotStartRaw,
                slot_end: slot.slotEndRaw,
                is_blocked: true,
                capacity_override: existing?.capacityOverride,
                note: existing?.note
            )

            try await client
                .from("venue_slot_overrides")
                .upsert(payload, onConflict: "profile_id,fulfillment_type,slot_start")
                .execute()
        } else {
            if let existing = try await fetchSlotOverride(
                profileId: profileId,
                slotStartISO: slot.slotStartRaw,
                fulfillmentType: fulfillmentType
            ) {
                if existing.capacityOverride == nil {
                    try await client
                        .from("venue_slot_overrides")
                        .delete()
                        .eq("profile_id", value: profileId.uuidString)
                        .eq("slot_start", value: slot.slotStartRaw)
                        .eq("fulfillment_type", value: fulfillmentType.rawValue)
                        .execute()
                } else {
                    let payload = SlotOverrideUpsertPayload(
                        profile_id: profileId,
                        fulfillment_type: fulfillmentType.rawValue,
                        slot_start: slot.slotStartRaw,
                        slot_end: slot.slotEndRaw,
                        is_blocked: false,
                        capacity_override: existing.capacityOverride,
                        note: existing.note
                    )

                    try await client
                        .from("venue_slot_overrides")
                        .upsert(payload, onConflict: "profile_id,fulfillment_type,slot_start")
                        .execute()
                }
            }
        }
    }

    func setSlotCapacityOverride(
        profileId: UUID,
        fulfillmentType: SlotFulfillmentType,
        slot: AvailableSlot,
        capacity: Int?
    ) async throws {
        let existing = try await fetchSlotOverride(
            profileId: profileId,
            slotStartISO: slot.slotStartRaw,
            fulfillmentType: fulfillmentType
        )

        if capacity == nil, (existing?.isBlocked ?? false) == false {
            try await client
                .from("venue_slot_overrides")
                .delete()
                .eq("profile_id", value: profileId.uuidString)
                .eq("slot_start", value: slot.slotStartRaw)
                .eq("fulfillment_type", value: fulfillmentType.rawValue)
                .execute()
            return
        }

        let payload = SlotOverrideUpsertPayload(
            profile_id: profileId,
            fulfillment_type: fulfillmentType.rawValue,
            slot_start: slot.slotStartRaw,
            slot_end: slot.slotEndRaw,
            is_blocked: existing?.isBlocked ?? false,
            capacity_override: capacity,
            note: existing?.note
        )

        try await client
            .from("venue_slot_overrides")
            .upsert(payload, onConflict: "profile_id,fulfillment_type,slot_start")
            .execute()
    }
}
