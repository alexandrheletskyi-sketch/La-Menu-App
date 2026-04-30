import Foundation
import Supabase
import PostgREST

private struct VenueSlotSettingsInsertPayload: Encodable, Sendable {
    let profile_id: UUID
    let slot_duration_minutes: Int
    let default_capacity: Int
    let days_ahead: Int
    let lead_time_minutes: Int
    let allow_asap: Bool
    let earliest_pickup_time_text: String?
}

private struct VenueSlotSettingsUpdatePayload: Encodable, Sendable {
    let slot_duration_minutes: Int
    let default_capacity: Int
    let days_ahead: Int
    let lead_time_minutes: Int
    let allow_asap: Bool
    let earliest_pickup_time_text: String?
}

private struct ProfileSlotIntervalUpdatePayload: Encodable, Sendable {
    let slot_interval_minutes: Int
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
        "profile_id, slot_duration_minutes, default_capacity, days_ahead, lead_time_minutes, allow_asap, earliest_pickup_time_text"

    private let dateOverrideSelect =
        "profile_id, override_date, fulfillment_type, is_closed, open_time, close_time, capacity_override, note, created_at, updated_at"

    private let timeOverrideSelect =
        "profile_id, override_date, fulfillment_type, slot_time, is_blocked, capacity_override, note, created_at, updated_at"

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()

        decoder.dateDecodingStrategy = .custom { value in
            let container = try value.singleValueContainer()
            let raw = try container.decode(String.self)

            if let date = ISO8601DateFormatter.supabase.date(from: raw) {
                return date
            }

            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime]

            if let date = fallback.date(from: raw) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: \(raw)"
            )
        }

        return decoder
    }

    func fetchSettings(profileId: UUID) async throws -> VenueSlotSettings {
        debugHeader("SERVICE fetchSettings START")
        debug("profileId", profileId.uuidString)

        do {
            let response = try await client
                .from("venue_slot_settings")
                .select(settingsSelect)
                .eq("profile_id", value: profileId.uuidString)
                .limit(1)
                .execute()

            debugPrintRawResponse(response.data, label: "fetchSettings raw")

            if isEmptyJSONArrayOrNoData(response.data) {
                debug("fetchSettings", "no settings found -> inserting default")
                return try await insertDefaultSettings(profileId: profileId)
            }

            let items = try decoder.decode([VenueSlotSettings].self, from: response.data)

            guard let first = items.first else {
                debug("fetchSettings", "decoded empty array -> inserting default")
                return try await insertDefaultSettings(profileId: profileId)
            }

            debug("fetchSettings success", first)
            return first
        } catch {
            debugError("fetchSettings", error)
            throw error
        }
    }

    private func insertDefaultSettings(profileId: UUID) async throws -> VenueSlotSettings {
        debugHeader("SERVICE insertDefaultSettings START")

        let fallback = VenueSlotSettings.placeholder(profileId: profileId)

        let payload = VenueSlotSettingsInsertPayload(
            profile_id: profileId,
            slot_duration_minutes: max(fallback.slotDurationMinutes, 5),
            default_capacity: max(fallback.defaultCapacity, 1),
            days_ahead: max(fallback.daysAhead, 1),
            lead_time_minutes: max(fallback.leadTimeMinutes, 0),
            allow_asap: fallback.allowAsap,
            earliest_pickup_time_text: normalizedOptionalText(fallback.earliestPickupTimeText)
        )

        debug("insertDefaultSettings payload", payload)

        do {
            let insertResponse = try await client
                .from("venue_slot_settings")
                .insert(payload)
                .execute()

            debugPrintRawResponse(insertResponse.data, label: "insertDefaultSettings insert raw")

            try await updateProfileSlotInterval(
                profileId: profileId,
                slotDurationMinutes: payload.slot_duration_minutes
            )
        } catch {
            debugError("insertDefaultSettings insert", error)
            throw error
        }

        let selectResponse = try await client
            .from("venue_slot_settings")
            .select(settingsSelect)
            .eq("profile_id", value: profileId.uuidString)
            .limit(1)
            .execute()

        debugPrintRawResponse(selectResponse.data, label: "insertDefaultSettings reselect raw")

        let items = try decoder.decode([VenueSlotSettings].self, from: selectResponse.data)

        guard let first = items.first else {
            throw NSError(
                domain: "SlotManagementService",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Nie udało się odczytać ustawień po zapisie"
                ]
            )
        }

        debug("insertDefaultSettings success", first)
        return first
    }

    func updateSettings(_ settings: VenueSlotSettings) async throws {
        debugHeader("SERVICE updateSettings START")

        let normalizedSlotDuration = max(settings.slotDurationMinutes, 5)

        let payload = VenueSlotSettingsUpdatePayload(
            slot_duration_minutes: normalizedSlotDuration,
            default_capacity: max(settings.defaultCapacity, 1),
            days_ahead: max(settings.daysAhead, 1),
            lead_time_minutes: max(settings.leadTimeMinutes, 0),
            allow_asap: settings.allowAsap,
            earliest_pickup_time_text: settings.allowAsap
                ? normalizedOptionalText(settings.earliestPickupTimeText)
                : nil
        )

        debug("profileId", settings.profileId.uuidString)
        debug("payload", payload)

        do {
            let response = try await client
                .from("venue_slot_settings")
                .update(payload)
                .eq("profile_id", value: settings.profileId.uuidString)
                .execute()

            debugPrintRawResponse(response.data, label: "updateSettings raw")

            try await updateProfileSlotInterval(
                profileId: settings.profileId,
                slotDurationMinutes: normalizedSlotDuration
            )

            debug("updateSettings", "success")
        } catch {
            debugError("updateSettings", error)
            throw error
        }
    }

    func updateProfileSlotInterval(
        profileId: UUID,
        slotDurationMinutes: Int
    ) async throws {
        debugHeader("SERVICE updateProfileSlotInterval START")

        let payload = ProfileSlotIntervalUpdatePayload(
            slot_interval_minutes: max(slotDurationMinutes, 5)
        )

        debug("profileId", profileId.uuidString)
        debug("payload", payload)

        do {
            let response = try await client
                .from("profiles")
                .update(payload)
                .eq("id", value: profileId.uuidString)
                .execute()

            debugPrintRawResponse(response.data, label: "updateProfileSlotInterval raw")
            debug("updateProfileSlotInterval", "success")
        } catch {
            debugError("updateProfileSlotInterval", error)
            throw error
        }
    }

    func fetchAdminDaySlots(
        profileId: UUID,
        date: Date,
        fulfillmentType: SlotFulfillmentType,
        timezone: String = "Europe/Warsaw"
    ) async throws -> [AdminDaySlot] {
        debugHeader("SERVICE fetchAdminDaySlots START")

        let dateString = DateFormatter.yyyyMMdd.string(from: date)

        let params: [String: String] = [
            "p_profile_id": profileId.uuidString,
            "p_target_date": dateString,
            "p_fulfillment_type": fulfillmentType.rawValue,
            "p_timezone": timezone
        ]

        debug("params", params)

        do {
            let response = try await client
                .rpc("get_day_slots_for_admin", params: params)
                .execute()

            debugPrintRawResponse(response.data, label: "get_day_slots_for_admin raw")

            if isEmptyJSONArrayOrNoData(response.data) {
                debug("fetchAdminDaySlots", "empty response -> []")
                return []
            }

            let decoded = try decoder.decode([AdminDaySlot].self, from: response.data)

            debug("fetchAdminDaySlots decoded count", decoded.count)

            for slot in decoded {
                print("🕒 SLOT")
                print("label: \(slot.slotLabel)")
                print("startRaw: \(slot.slotStartRaw)")
                print("isBlocked: \(slot.isBlocked)")
                print("status: \(slot.status)")
                print("statusTitle: \(slot.statusTitle)")
                print("capacity: \(slot.capacity)")
                print("taken: \(slot.taken)")
                print("remaining: \(slot.remaining)")
                print("hasCapacityOverride: \(slot.hasCapacityOverride)")
                print("------------------------------")
            }

            return decoded
        } catch {
            debugError("fetchAdminDaySlots", error)
            throw error
        }
    }

    func fetchDateOverride(
        profileId: UUID,
        date: Date,
        fulfillmentType: SlotFulfillmentType
    ) async throws -> SlotDateOverride? {
        debugHeader("SERVICE fetchDateOverride START")

        let dateString = DateFormatter.yyyyMMdd.string(from: date)

        debug("profileId", profileId.uuidString)
        debug("date", dateString)
        debug("fulfillmentType", fulfillmentType.rawValue)

        do {
            let response = try await client
                .from("venue_slot_date_overrides")
                .select(dateOverrideSelect)
                .eq("profile_id", value: profileId.uuidString)
                .eq("override_date", value: dateString)
                .eq("fulfillment_type", value: fulfillmentType.rawValue)
                .limit(1)
                .execute()

            debugPrintRawResponse(response.data, label: "fetchDateOverride raw")

            if isEmptyJSONArrayOrNoData(response.data) {
                debug("fetchDateOverride", "not found")
                return nil
            }

            let items = try decoder.decode([SlotDateOverride].self, from: response.data)
            debug("fetchDateOverride count", items.count)

            return items.first
        } catch {
            debugError("fetchDateOverride", error)
            throw error
        }
    }

    func upsertDateOverride(
        profileId: UUID,
        date: Date,
        fulfillmentType: SlotFulfillmentType,
        draft: SlotDateOverrideDraft
    ) async throws {
        debugHeader("SERVICE upsertDateOverride START")

        let payload = SlotDateOverrideUpsertPayload(
            profile_id: profileId,
            override_date: DateFormatter.yyyyMMdd.string(from: date),
            fulfillment_type: fulfillmentType.rawValue,
            is_closed: draft.isClosed,
            open_time: draft.isClosed ? nil : DateFormatter.hm24.string(from: draft.openDate),
            close_time: draft.isClosed ? nil : DateFormatter.hm24.string(from: draft.closeDate),
            capacity_override: normalizedPositiveInt(draft.capacityOverride),
            note: normalizedOptionalText(draft.note)
        )

        debug("payload", payload)

        do {
            let response = try await client
                .from("venue_slot_date_overrides")
                .upsert(payload, onConflict: "profile_id,override_date,fulfillment_type")
                .execute()

            debugPrintRawResponse(response.data, label: "upsertDateOverride raw")
            debug("upsertDateOverride", "success")
        } catch {
            debugError("upsertDateOverride", error)
            throw error
        }
    }

    func deleteDateOverride(
        profileId: UUID,
        date: Date,
        fulfillmentType: SlotFulfillmentType
    ) async throws {
        debugHeader("SERVICE deleteDateOverride START")

        let dateString = DateFormatter.yyyyMMdd.string(from: date)

        debug("profileId", profileId.uuidString)
        debug("date", dateString)
        debug("fulfillmentType", fulfillmentType.rawValue)

        do {
            let response = try await client
                .from("venue_slot_date_overrides")
                .delete()
                .eq("profile_id", value: profileId.uuidString)
                .eq("override_date", value: dateString)
                .eq("fulfillment_type", value: fulfillmentType.rawValue)
                .execute()

            debugPrintRawResponse(response.data, label: "deleteDateOverride raw")
            debug("deleteDateOverride", "success")
        } catch {
            debugError("deleteDateOverride", error)
            throw error
        }
    }

    func fetchSlotTimeOverride(
        profileId: UUID,
        date: Date,
        slotTime: String,
        fulfillmentType: SlotFulfillmentType
    ) async throws -> SlotTimeOverride? {
        debugHeader("SERVICE fetchSlotTimeOverride START")

        let dateString = DateFormatter.yyyyMMdd.string(from: date)
        let normalizedTargetForCompare = normalizeTimeForCompare(slotTime)
        let normalizedTargetForDatabase = normalizeSlotTimeForDatabase(slotTime)

        debug("profileId", profileId.uuidString)
        debug("date", dateString)
        debug("fulfillmentType", fulfillmentType.rawValue)
        debug("slotTime input", slotTime)
        debug("normalizedTargetForCompare", normalizedTargetForCompare)
        debug("normalizedTargetForDatabase", normalizedTargetForDatabase)

        do {
            let response = try await client
                .from("venue_slot_time_overrides")
                .select(timeOverrideSelect)
                .eq("profile_id", value: profileId.uuidString)
                .eq("override_date", value: dateString)
                .eq("fulfillment_type", value: fulfillmentType.rawValue)
                .execute()

            debugPrintRawResponse(response.data, label: "fetchSlotTimeOverride raw")

            if isEmptyJSONArrayOrNoData(response.data) {
                debug("fetchSlotTimeOverride", "no rows")
                return nil
            }

            let items = try decoder.decode([SlotTimeOverride].self, from: response.data)

            debug("fetchSlotTimeOverride rows count", items.count)

            for item in items {
                print("""
                🔎 OVERRIDE ROW
                slotTime DB: \(item.slotTime)
                normalized DB: \(normalizeTimeForCompare(item.slotTime))
                target: \(normalizedTargetForCompare)
                isBlocked: \(item.isBlocked)
                capacityOverride: \(String(describing: item.capacityOverride))
                note: \(String(describing: item.note))
                ------------------------------
                """)
            }

            let matched = items.first { item in
                normalizeTimeForCompare(item.slotTime) == normalizedTargetForCompare
            }

            debug("fetchSlotTimeOverride matched", String(describing: matched))

            return matched
        } catch {
            debugError("fetchSlotTimeOverride", error)
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
        debugHeader("SERVICE setSlotBlocked START")

        let dateString = DateFormatter.yyyyMMdd.string(from: date)
        let requestedSlotTime = slot.slotStartRaw
        let normalizedSlotTime = normalizeSlotTimeForDatabase(requestedSlotTime)

        debug("profileId", profileId.uuidString)
        debug("date", dateString)
        debug("fulfillmentType", fulfillmentType.rawValue)
        debug("slot.slotLabel", slot.slotLabel)
        debug("slot.slotStartRaw", slot.slotStartRaw)
        debug("requestedSlotTime", requestedSlotTime)
        debug("normalizedSlotTime", normalizedSlotTime)
        debug("blocked target", blocked)
        debug("current slot.isBlocked", slot.isBlocked)
        debug("current slot.status", "\(slot.status)")

        let existing = try await fetchSlotTimeOverride(
            profileId: profileId,
            date: date,
            slotTime: requestedSlotTime,
            fulfillmentType: fulfillmentType
        )

        debug("existing override before change", String(describing: existing))

        if blocked == false {
            if let existing, existing.capacityOverride == nil {
                debug("setSlotBlocked", "unblock -> deleting existing override row")
                debug("delete slot_time exact", existing.slotTime)

                do {
                    let response = try await client
                        .from("venue_slot_time_overrides")
                        .delete()
                        .eq("profile_id", value: profileId.uuidString)
                        .eq("override_date", value: dateString)
                        .eq("fulfillment_type", value: fulfillmentType.rawValue)
                        .eq("slot_time", value: existing.slotTime)
                        .execute()

                    debugPrintRawResponse(response.data, label: "setSlotBlocked delete raw")
                    debug("setSlotBlocked delete", "success")

                    let after = try await fetchSlotTimeOverride(
                        profileId: profileId,
                        date: date,
                        slotTime: requestedSlotTime,
                        fulfillmentType: fulfillmentType
                    )

                    debug("existing override after delete", String(describing: after))
                    return
                } catch {
                    debugError("setSlotBlocked delete", error)
                    throw error
                }
            }

            if existing == nil {
                debug("setSlotBlocked", "unblock requested but override not found -> nothing to delete")
                return
            }
        }

        let payload = SlotTimeOverrideUpsertPayload(
            profile_id: profileId,
            override_date: dateString,
            fulfillment_type: fulfillmentType.rawValue,
            slot_time: existing?.slotTime ?? normalizedSlotTime,
            is_blocked: blocked,
            capacity_override: existing?.capacityOverride,
            note: existing?.note
        )

        debug("setSlotBlocked upsert payload", payload)

        do {
            let response = try await client
                .from("venue_slot_time_overrides")
                .upsert(payload, onConflict: "profile_id,override_date,fulfillment_type,slot_time")
                .execute()

            debugPrintRawResponse(response.data, label: "setSlotBlocked upsert raw")
            debug("setSlotBlocked upsert", "success")

            let after = try await fetchSlotTimeOverride(
                profileId: profileId,
                date: date,
                slotTime: requestedSlotTime,
                fulfillmentType: fulfillmentType
            )

            debug("existing override after upsert", String(describing: after))
        } catch {
            debugError("setSlotBlocked upsert", error)
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
        debugHeader("SERVICE setSlotCapacityOverride START")

        let dateString = DateFormatter.yyyyMMdd.string(from: date)
        let requestedSlotTime = slot.slotStartRaw
        let normalizedSlotTime = normalizeSlotTimeForDatabase(requestedSlotTime)

        debug("profileId", profileId.uuidString)
        debug("date", dateString)
        debug("fulfillmentType", fulfillmentType.rawValue)
        debug("slot.slotLabel", slot.slotLabel)
        debug("slot.slotStartRaw", slot.slotStartRaw)
        debug("requestedSlotTime", requestedSlotTime)
        debug("normalizedSlotTime", normalizedSlotTime)
        debug("capacity input", String(describing: capacity))

        let existing = try await fetchSlotTimeOverride(
            profileId: profileId,
            date: date,
            slotTime: requestedSlotTime,
            fulfillmentType: fulfillmentType
        )

        debug("existing override before capacity change", String(describing: existing))

        let normalizedCapacity = capacity.map { max($0, 1) }

        debug("normalized capacity", String(describing: normalizedCapacity))

        if normalizedCapacity == nil, (existing?.isBlocked ?? false) == false {
            if let existing {
                debug("setSlotCapacityOverride", "capacity nil and not blocked -> deleting row")
                debug("delete slot_time exact", existing.slotTime)

                do {
                    let response = try await client
                        .from("venue_slot_time_overrides")
                        .delete()
                        .eq("profile_id", value: profileId.uuidString)
                        .eq("override_date", value: dateString)
                        .eq("fulfillment_type", value: fulfillmentType.rawValue)
                        .eq("slot_time", value: existing.slotTime)
                        .execute()

                    debugPrintRawResponse(response.data, label: "setSlotCapacityOverride delete raw")
                    debug("setSlotCapacityOverride delete", "success")
                    return
                } catch {
                    debugError("setSlotCapacityOverride delete", error)
                    throw error
                }
            } else {
                debug("setSlotCapacityOverride", "no existing override to delete")
                return
            }
        }

        let payload = SlotTimeOverrideUpsertPayload(
            profile_id: profileId,
            override_date: dateString,
            fulfillment_type: fulfillmentType.rawValue,
            slot_time: existing?.slotTime ?? normalizedSlotTime,
            is_blocked: existing?.isBlocked ?? false,
            capacity_override: normalizedCapacity,
            note: existing?.note
        )

        debug("setSlotCapacityOverride upsert payload", payload)

        do {
            let response = try await client
                .from("venue_slot_time_overrides")
                .upsert(payload, onConflict: "profile_id,override_date,fulfillment_type,slot_time")
                .execute()

            debugPrintRawResponse(response.data, label: "setSlotCapacityOverride upsert raw")
            debug("setSlotCapacityOverride upsert", "success")

            let after = try await fetchSlotTimeOverride(
                profileId: profileId,
                date: date,
                slotTime: requestedSlotTime,
                fulfillmentType: fulfillmentType
            )

            debug("existing override after capacity upsert", String(describing: after))
        } catch {
            debugError("setSlotCapacityOverride upsert", error)
            throw error
        }
    }

    private func normalizeSlotTimeForDatabase(_ value: String) -> String {
        let raw = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if raw.count >= 19, raw.contains("T") {
            let start = raw.index(raw.startIndex, offsetBy: 11)
            let end = raw.index(start, offsetBy: 8)
            let result = String(raw[start..<end])
            debug("normalizeSlotTimeForDatabase ISO", "\(raw) -> \(result)")
            return result
        }

        if raw.count >= 8, raw.filter({ $0 == ":" }).count >= 2 {
            let result = String(raw.prefix(8))
            debug("normalizeSlotTimeForDatabase HH:mm:ss", "\(raw) -> \(result)")
            return result
        }

        if raw.count >= 5, raw.contains(":") {
            let result = String(raw.prefix(5)) + ":00"
            debug("normalizeSlotTimeForDatabase HH:mm", "\(raw) -> \(result)")
            return result
        }

        debug("normalizeSlotTimeForDatabase raw", raw)
        return raw
    }

    private func normalizeTimeForCompare(_ value: String) -> String {
        let raw = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if raw.count >= 19, raw.contains("T") {
            let start = raw.index(raw.startIndex, offsetBy: 11)
            let end = raw.index(start, offsetBy: 5)
            return String(raw[start..<end])
        }

        if raw.count >= 8, raw.filter({ $0 == ":" }).count >= 2 {
            return String(raw.prefix(5))
        }

        if raw.count >= 5, raw.contains(":") {
            return String(raw.prefix(5))
        }

        return raw
    }

    private func normalizedOptionalText(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizedPositiveInt(_ value: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let intValue = Int(trimmed), intValue >= 1 else {
            return nil
        }

        return intValue
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
            print("📦 DEBUG \(label): <empty>")
            return
        }

        if let raw = String(data: data, encoding: .utf8) {
            print("""
            📦 DEBUG \(label):
            \(raw)
            """)
        } else {
            print("📦 DEBUG \(label): <non-utf8 data, bytes=\(data.count)>")
        }
    }

    private func debugHeader(_ title: String) {
        print("""
        
        🟧 ==============================
        🟧 \(title)
        🟧 ==============================
        """)
    }

    private func debug(_ key: String, _ value: Any) {
        print("🔸 DEBUG \(key): \(value)")
    }

    private func debugError(_ label: String, _ error: Error) {
        print("""
        ❌ DEBUG ERROR \(label)
        error: \(error)
        localizedDescription: \(error.localizedDescription)
        """)
    }
}
