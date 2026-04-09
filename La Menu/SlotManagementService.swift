import Foundation
import Supabase
import PostgREST

private struct VenueSlotSettingsInsertPayload: Encodable, Sendable {
    let profile_id: UUID
    let slot_duration: Int
    let default_capacity: Int
    let days_ahead: Int
    let lead_time_min: Int
    let allow_asap: Bool
    let earliest_pickup_time_text: String?
}

private struct VenueSlotSettingsUpdatePayload: Encodable, Sendable {
    let slot_duration: Int
    let default_capacity: Int
    let days_ahead: Int
    let lead_time_min: Int
    let allow_asap: Bool
    let earliest_pickup_time_text: String?
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

private struct SlotTimeOverrideUpsertPayload: Encodable, Sendable {
    let profile_id: UUID
    let override_date: String
    let fulfillment_type: String
    let slot_time: String
    let is_blocked: Bool
    let capacity_override: Int?
    let note: String?
}

struct SlotManagementService {
    private let client = SupabaseManager.shared

    private let settingsSelect =
        "profile_id, slot_duration, default_capacity, days_ahead, lead_time_min, allow_asap, earliest_pickup_time_text"

    func fetchSettings(profileId: UUID) async throws -> VenueSlotSettings {
        print("DEBUG Service fetchSettings start")
        print("DEBUG Service fetchSettings profileId:", profileId.uuidString)

        do {
            let response = try await client
                .from("venue_slot_settings")
                .select(settingsSelect)
                .eq("profile_id", value: profileId.uuidString)
                .limit(1)
                .execute()

            debugPrintRawResponse(response.data, label: "fetchSettings select raw")

            if isEmptyJSONArrayOrNoData(response.data) {
                print("DEBUG Service fetchSettings no existing settings -> insert default")
                return try await insertDefaultSettings(profileId: profileId)
            }

            let items = try JSONDecoder().decode([VenueSlotSettings].self, from: response.data)

            guard let first = items.first else {
                print("DEBUG Service fetchSettings decoded empty array -> insert default")
                return try await insertDefaultSettings(profileId: profileId)
            }

            print("DEBUG Service fetchSettings found existing settings:", first)
            return first
        } catch {
            print("DEBUG Service fetchSettings ERROR:", error)
            print("DEBUG Service fetchSettings ERROR description:", error.localizedDescription)
            throw error
        }
    }

    private func insertDefaultSettings(profileId: UUID) async throws -> VenueSlotSettings {
        let fallback = VenueSlotSettings.placeholder(profileId: profileId)

        let payload = VenueSlotSettingsInsertPayload(
            profile_id: profileId,
            slot_duration: fallback.slotDurationMinutes,
            default_capacity: fallback.defaultCapacity,
            days_ahead: fallback.daysAhead,
            lead_time_min: fallback.leadTimeMinutes,
            allow_asap: fallback.allowAsap,
            earliest_pickup_time_text: normalizedOptionalText(fallback.earliestPickupTimeText)
        )

        print("DEBUG Service insertDefaultSettings payload:", payload)

        do {
            let insertResponse = try await client
                .from("venue_slot_settings")
                .insert(payload)
                .execute()

            debugPrintRawResponse(insertResponse.data, label: "insertDefaultSettings insert raw")
        } catch {
            print("DEBUG Service insertDefaultSettings insert ERROR:", error)
            print("DEBUG Service insertDefaultSettings insert ERROR description:", error.localizedDescription)
            throw error
        }

        let selectResponse = try await client
            .from("venue_slot_settings")
            .select(settingsSelect)
            .eq("profile_id", value: profileId.uuidString)
            .limit(1)
            .execute()

        debugPrintRawResponse(selectResponse.data, label: "insertDefaultSettings reselect raw")

        let items = try JSONDecoder().decode([VenueSlotSettings].self, from: selectResponse.data)

        guard let first = items.first else {
            throw NSError(
                domain: "SlotManagementService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Nie udało się odczytać ustawień po zapisie"]
            )
        }

        print("DEBUG Service insertDefaultSettings success:", first)
        return first
    }

    func updateSettings(_ settings: VenueSlotSettings) async throws {
        let payload = VenueSlotSettingsUpdatePayload(
            slot_duration: max(settings.slotDurationMinutes, 5),
            default_capacity: max(settings.defaultCapacity, 1),
            days_ahead: max(settings.daysAhead, 1),
            lead_time_min: max(settings.leadTimeMinutes, 0),
            allow_asap: settings.allowAsap,
            earliest_pickup_time_text: settings.allowAsap
                ? normalizedOptionalText(settings.earliestPickupTimeText)
                : nil
        )

        print("DEBUG Service updateSettings start")
        print("DEBUG Service updateSettings profileId:", settings.profileId.uuidString)
        print("DEBUG Service updateSettings payload:", payload)

        do {
            let response = try await client
                .from("venue_slot_settings")
                .update(payload)
                .eq("profile_id", value: settings.profileId.uuidString)
                .execute()

            debugPrintRawResponse(response.data, label: "updateSettings raw")
            print("DEBUG Service updateSettings success")
        } catch {
            print("DEBUG Service updateSettings ERROR:", error)
            print("DEBUG Service updateSettings ERROR description:", error.localizedDescription)
            throw error
        }
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

        print("DEBUG Service fetchAdminDaySlots start")
        print("DEBUG Service fetchAdminDaySlots params:", params)

        do {
            let response = try await client
                .rpc("get_day_slots_for_admin", params: params)
                .execute()

            debugPrintRawResponse(response.data, label: "get_day_slots_for_admin raw")

            if isEmptyJSONArrayOrNoData(response.data) {
                print("DEBUG Service fetchAdminDaySlots empty data, returning []")
                return []
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let decoded = try decoder.decode([AdminDaySlot].self, from: response.data)
            print("DEBUG Service fetchAdminDaySlots decoded count:", decoded.count)
            return decoded
        } catch {
            print("DEBUG Service fetchAdminDaySlots ERROR:", error)
            print("DEBUG Service fetchAdminDaySlots ERROR description:", error.localizedDescription)
            throw error
        }
    }

    func fetchDateOverride(
        profileId: UUID,
        date: Date,
        fulfillmentType: SlotFulfillmentType
    ) async throws -> SlotDateOverride? {
        print("DEBUG Service fetchDateOverride start")
        print("DEBUG Service fetchDateOverride profileId:", profileId.uuidString)
        print("DEBUG Service fetchDateOverride date:", DateFormatter.yyyyMMdd.string(from: date))
        print("DEBUG Service fetchDateOverride fulfillmentType:", fulfillmentType.rawValue)

        do {
            let response = try await client
                .from("venue_slot_date_overrides")
                .select()
                .eq("profile_id", value: profileId.uuidString)
                .eq("override_date", value: DateFormatter.yyyyMMdd.string(from: date))
                .eq("fulfillment_type", value: fulfillmentType.rawValue)
                .limit(1)
                .execute()

            debugPrintRawResponse(response.data, label: "fetchDateOverride raw")

            if isEmptyJSONArrayOrNoData(response.data) {
                return nil
            }

            let items = try JSONDecoder().decode([SlotDateOverride].self, from: response.data)
            print("DEBUG Service fetchDateOverride items count:", items.count)
            return items.first
        } catch {
            print("DEBUG Service fetchDateOverride ERROR:", error)
            print("DEBUG Service fetchDateOverride ERROR description:", error.localizedDescription)
            throw error
        }
    }

    func upsertDateOverride(
        profileId: UUID,
        date: Date,
        fulfillmentType: SlotFulfillmentType,
        draft: SlotDateOverrideDraft
    ) async throws {
        let payload = SlotDateOverrideUpsertPayload(
            profile_id: profileId,
            override_date: DateFormatter.yyyyMMdd.string(from: date),
            fulfillment_type: fulfillmentType.rawValue,
            is_closed: draft.isClosed,
            open_time: draft.isClosed ? nil : DateFormatter.hm24.string(from: draft.openDate),
            close_time: draft.isClosed ? nil : DateFormatter.hm24.string(from: draft.closeDate),
            capacity_override: Int(draft.capacityOverride.trimmingCharacters(in: .whitespacesAndNewlines)),
            note: normalizedOptionalText(draft.note)
        )

        print("DEBUG Service upsertDateOverride start")
        print("DEBUG Service upsertDateOverride payload:", payload)

        do {
            let response = try await client
                .from("venue_slot_date_overrides")
                .upsert(payload, onConflict: "profile_id,override_date,fulfillment_type")
                .execute()

            debugPrintRawResponse(response.data, label: "upsertDateOverride raw")
            print("DEBUG Service upsertDateOverride success")
        } catch {
            print("DEBUG Service upsertDateOverride ERROR:", error)
            print("DEBUG Service upsertDateOverride ERROR description:", error.localizedDescription)
            throw error
        }
    }

    func deleteDateOverride(
        profileId: UUID,
        date: Date,
        fulfillmentType: SlotFulfillmentType
    ) async throws {
        print("DEBUG Service deleteDateOverride start")
        print("DEBUG Service deleteDateOverride profileId:", profileId.uuidString)
        print("DEBUG Service deleteDateOverride date:", DateFormatter.yyyyMMdd.string(from: date))
        print("DEBUG Service deleteDateOverride fulfillmentType:", fulfillmentType.rawValue)

        do {
            let response = try await client
                .from("venue_slot_date_overrides")
                .delete()
                .eq("profile_id", value: profileId.uuidString)
                .eq("override_date", value: DateFormatter.yyyyMMdd.string(from: date))
                .eq("fulfillment_type", value: fulfillmentType.rawValue)
                .execute()

            debugPrintRawResponse(response.data, label: "deleteDateOverride raw")
            print("DEBUG Service deleteDateOverride success")
        } catch {
            print("DEBUG Service deleteDateOverride ERROR:", error)
            print("DEBUG Service deleteDateOverride ERROR description:", error.localizedDescription)
            throw error
        }
    }

    func fetchSlotTimeOverride(
        profileId: UUID,
        date: Date,
        slotTime: String,
        fulfillmentType: SlotFulfillmentType
    ) async throws -> SlotTimeOverride? {
        print("DEBUG Service fetchSlotTimeOverride start")
        print("DEBUG Service fetchSlotTimeOverride profileId:", profileId.uuidString)
        print("DEBUG Service fetchSlotTimeOverride date:", DateFormatter.yyyyMMdd.string(from: date))
        print("DEBUG Service fetchSlotTimeOverride slotTime:", slotTime)
        print("DEBUG Service fetchSlotTimeOverride fulfillmentType:", fulfillmentType.rawValue)

        do {
            let response = try await client
                .from("venue_slot_time_overrides")
                .select()
                .eq("profile_id", value: profileId.uuidString)
                .eq("override_date", value: DateFormatter.yyyyMMdd.string(from: date))
                .eq("slot_time", value: slotTime)
                .eq("fulfillment_type", value: fulfillmentType.rawValue)
                .limit(1)
                .execute()

            debugPrintRawResponse(response.data, label: "fetchSlotTimeOverride raw")

            if isEmptyJSONArrayOrNoData(response.data) {
                return nil
            }

            let items = try JSONDecoder().decode([SlotTimeOverride].self, from: response.data)
            print("DEBUG Service fetchSlotTimeOverride items count:", items.count)
            return items.first
        } catch {
            print("DEBUG Service fetchSlotTimeOverride ERROR:", error)
            print("DEBUG Service fetchSlotTimeOverride ERROR description:", error.localizedDescription)
            throw error
        }
    }

    func setSlotBlocked(
        profileId: UUID,
        date: Date,
        fulfillmentType: SlotFulfillmentType,
        slot: AdminDaySlot,
        blocked: Bool
    ) async throws {
        print("DEBUG Service setSlotBlocked start")
        print("DEBUG Service setSlotBlocked profileId:", profileId.uuidString)
        print("DEBUG Service setSlotBlocked date:", DateFormatter.yyyyMMdd.string(from: date))
        print("DEBUG Service setSlotBlocked fulfillmentType:", fulfillmentType.rawValue)
        print("DEBUG Service setSlotBlocked slotStartRaw:", slot.slotStartRaw)
        print("DEBUG Service setSlotBlocked blocked:", blocked)

        let existing = try await fetchSlotTimeOverride(
            profileId: profileId,
            date: date,
            slotTime: slot.slotStartRaw,
            fulfillmentType: fulfillmentType
        )

        print("DEBUG Service setSlotBlocked existing override:", String(describing: existing))

        if !blocked, existing?.capacityOverride == nil {
            print("DEBUG Service setSlotBlocked deleting override because blocked=false and no capacity override")

            do {
                let response = try await client
                    .from("venue_slot_time_overrides")
                    .delete()
                    .eq("profile_id", value: profileId.uuidString)
                    .eq("override_date", value: DateFormatter.yyyyMMdd.string(from: date))
                    .eq("slot_time", value: slot.slotStartRaw)
                    .eq("fulfillment_type", value: fulfillmentType.rawValue)
                    .execute()

                debugPrintRawResponse(response.data, label: "setSlotBlocked delete raw")
                print("DEBUG Service setSlotBlocked delete success")
                return
            } catch {
                print("DEBUG Service setSlotBlocked delete ERROR:", error)
                print("DEBUG Service setSlotBlocked delete ERROR description:", error.localizedDescription)
                throw error
            }
        }

        let payload = SlotTimeOverrideUpsertPayload(
            profile_id: profileId,
            override_date: DateFormatter.yyyyMMdd.string(from: date),
            fulfillment_type: fulfillmentType.rawValue,
            slot_time: slot.slotStartRaw,
            is_blocked: blocked,
            capacity_override: existing?.capacityOverride,
            note: existing?.note
        )

        print("DEBUG Service setSlotBlocked upsert payload:", payload)

        do {
            let response = try await client
                .from("venue_slot_time_overrides")
                .upsert(payload, onConflict: "profile_id,override_date,fulfillment_type,slot_time")
                .execute()

            debugPrintRawResponse(response.data, label: "setSlotBlocked upsert raw")
            print("DEBUG Service setSlotBlocked upsert success")
        } catch {
            print("DEBUG Service setSlotBlocked upsert ERROR:", error)
            print("DEBUG Service setSlotBlocked upsert ERROR description:", error.localizedDescription)
            throw error
        }
    }

    func setSlotCapacityOverride(
        profileId: UUID,
        date: Date,
        fulfillmentType: SlotFulfillmentType,
        slot: AdminDaySlot,
        capacity: Int?
    ) async throws {
        print("DEBUG Service setSlotCapacityOverride start")
        print("DEBUG Service setSlotCapacityOverride profileId:", profileId.uuidString)
        print("DEBUG Service setSlotCapacityOverride date:", DateFormatter.yyyyMMdd.string(from: date))
        print("DEBUG Service setSlotCapacityOverride fulfillmentType:", fulfillmentType.rawValue)
        print("DEBUG Service setSlotCapacityOverride slotStartRaw:", slot.slotStartRaw)
        print("DEBUG Service setSlotCapacityOverride capacity input:", String(describing: capacity))

        let existing = try await fetchSlotTimeOverride(
            profileId: profileId,
            date: date,
            slotTime: slot.slotStartRaw,
            fulfillmentType: fulfillmentType
        )

        print("DEBUG Service setSlotCapacityOverride existing override:", String(describing: existing))

        let normalizedCapacity = capacity.map { max($0, 1) }
        print("DEBUG Service setSlotCapacityOverride normalized capacity:", String(describing: normalizedCapacity))

        if normalizedCapacity == nil, (existing?.isBlocked ?? false) == false {
            print("DEBUG Service setSlotCapacityOverride deleting override because capacity=nil and not blocked")

            do {
                let response = try await client
                    .from("venue_slot_time_overrides")
                    .delete()
                    .eq("profile_id", value: profileId.uuidString)
                    .eq("override_date", value: DateFormatter.yyyyMMdd.string(from: date))
                    .eq("slot_time", value: slot.slotStartRaw)
                    .eq("fulfillment_type", value: fulfillmentType.rawValue)
                    .execute()

                debugPrintRawResponse(response.data, label: "setSlotCapacityOverride delete raw")
                print("DEBUG Service setSlotCapacityOverride delete success")
                return
            } catch {
                print("DEBUG Service setSlotCapacityOverride delete ERROR:", error)
                print("DEBUG Service setSlotCapacityOverride delete ERROR description:", error.localizedDescription)
                throw error
            }
        }

        let payload = SlotTimeOverrideUpsertPayload(
            profile_id: profileId,
            override_date: DateFormatter.yyyyMMdd.string(from: date),
            fulfillment_type: fulfillmentType.rawValue,
            slot_time: slot.slotStartRaw,
            is_blocked: existing?.isBlocked ?? false,
            capacity_override: normalizedCapacity,
            note: existing?.note
        )

        print("DEBUG Service setSlotCapacityOverride upsert payload:", payload)

        do {
            let response = try await client
                .from("venue_slot_time_overrides")
                .upsert(payload, onConflict: "profile_id,override_date,fulfillment_type,slot_time")
                .execute()

            debugPrintRawResponse(response.data, label: "setSlotCapacityOverride upsert raw")
            print("DEBUG Service setSlotCapacityOverride upsert success")
        } catch {
            print("DEBUG Service setSlotCapacityOverride upsert ERROR:", error)
            print("DEBUG Service setSlotCapacityOverride upsert ERROR description:", error.localizedDescription)
            throw error
        }
    }

    private func normalizedOptionalText(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func isEmptyJSONArrayOrNoData(_ data: Data) -> Bool {
        if data.isEmpty {
            return true
        }

        let raw = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return raw.isEmpty || raw == "[]"
    }

    private func debugPrintRawResponse(_ data: Data, label: String) {
        if data.isEmpty {
            print("DEBUG \(label): <empty>")
            return
        }

        if let raw = String(data: data, encoding: .utf8) {
            print("DEBUG \(label):\n\(raw)")
        } else {
            print("DEBUG \(label): <non-utf8 data, bytes=\(data.count)>")
        }
    }
}
