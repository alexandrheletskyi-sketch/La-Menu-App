import Foundation
import Observation

@MainActor
@Observable
final class SlotManagementViewModel {
    var settings: VenueSlotSettings?
    var selectedDate: Date = .now
    var selectedFulfillmentType: SlotFulfillmentType = .pickup
    var adminSlots: [AdminDaySlot] = []
    var dateOverrideDraft: SlotDateOverrideDraft = .empty

    var isLoading = false
    var isSavingSettings = false
    var isLoadingSlots = false
    var errorMessage: String?
    var successMessage: String?

    private let service = SlotManagementService()
    private let profileId: UUID

    init(profileId: UUID) {
        self.profileId = profileId

        print("🧩 SlotManagementViewModel INIT")
        print("🆔 profileId:", profileId)
    }

    var availableDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let count = max(settings?.daysAhead ?? 7, 1)

        return (0..<count).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today)
        }
    }

    func load() async {
        print("🟠 VM load START")
        print("🆔 profileId:", profileId)

        isLoading = true
        errorMessage = nil
        successMessage = nil

        defer {
            isLoading = false
            print("🟢 VM load END")
        }

        do {
            print("🚀 Fetching slot settings...")

            let fetchedSettings = try await service.fetchSettings(profileId: profileId)

            print("✅ Settings fetched")
            print("⏱ slotDurationMinutes:", fetchedSettings.slotDurationMinutes)
            print("📦 defaultCapacity:", fetchedSettings.defaultCapacity)
            print("📅 daysAhead:", fetchedSettings.daysAhead)
            print("⚡ allowAsap:", fetchedSettings.allowAsap)
            print("📝 earliestPickupTimeText:", fetchedSettings.earliestPickupTimeText)

            settings = fetchedSettings

            if !availableDates.contains(where: { Calendar.current.isDate($0, inSameDayAs: selectedDate) }) {
                print("📅 selectedDate outside available dates, resetting to today")
                selectedDate = Calendar.current.startOfDay(for: .now)
            }

            await loadDateOverride()
            await loadSlots()
        } catch {
            print("❌ VM load ERROR:", error)
            print("❌ localized:", error.localizedDescription)

            errorMessage = "Nie udało się wczytać ustawień slotów: \(error.localizedDescription)"
        }
    }

    func loadSlots() async {
        print("🟠 loadSlots START")
        print("🆔 profileId:", profileId)
        print("📅 selectedDate:", selectedDate)
        print("📦 fulfillmentType:", selectedFulfillmentType)

        guard settings != nil else {
            print("⚠️ loadSlots stopped: settings is nil")
            return
        }

        isLoadingSlots = true
        errorMessage = nil

        defer {
            isLoadingSlots = false
            print("🟢 loadSlots END")
        }

        do {
            let slots = try await service.fetchAdminDaySlots(
                profileId: profileId,
                date: selectedDate,
                fulfillmentType: selectedFulfillmentType
            )

            adminSlots = slots

            print("✅ Slots fetched count:", slots.count)

            for slot in slots {
                print("""
                ───────────────
                🕒 slotLabel: \(slot.slotLabel)
                🔒 isBlocked: \(slot.isBlocked)
                📌 status: \(slot.status)
                🏷 statusTitle: \(slot.statusTitle)
                📦 capacity: \(slot.capacity)
                📦 capacityOverrideValue: \(String(describing: slot.capacityOverrideValue))
                📦 hasCapacityOverride: \(slot.hasCapacityOverride)
                🧾 taken: \(slot.taken)
                🧾 remaining: \(slot.remaining)
                ───────────────
                """)
            }
        } catch {
            print("❌ loadSlots ERROR:", error)
            print("❌ localized:", error.localizedDescription)

            adminSlots = []
            errorMessage = "Nie udało się wczytać slotów: \(error.localizedDescription)"
        }
    }

    func loadDateOverride() async {
        print("🟠 loadDateOverride START")
        print("📅 selectedDate:", selectedDate)
        print("📦 fulfillmentType:", selectedFulfillmentType)

        do {
            if let override = try await service.fetchDateOverride(
                profileId: profileId,
                date: selectedDate,
                fulfillmentType: selectedFulfillmentType
            ) {
                print("✅ Date override found")
                print("🚪 isClosed:", override.isClosed)
                print("🕘 openTime:", String(describing: override.openTime))
                print("🕙 closeTime:", String(describing: override.closeTime))
                print("📦 capacityOverride:", String(describing: override.capacityOverride))
                print("📝 note:", String(describing: override.note))

                dateOverrideDraft = draft(from: override, baseDate: selectedDate)
            } else {
                print("ℹ️ No date override found")
                dateOverrideDraft = .empty
            }
        } catch {
            print("❌ loadDateOverride ERROR:", error)
            print("❌ localized:", error.localizedDescription)

            dateOverrideDraft = .empty
        }

        print("🟢 loadDateOverride END")
    }

    func saveSettings() async {
        print("🟠 saveSettings START")

        guard var settings else {
            print("⚠️ saveSettings stopped: settings is nil")
            return
        }

        isSavingSettings = true
        errorMessage = nil
        successMessage = nil

        defer {
            isSavingSettings = false
            print("🟢 saveSettings END")
        }

        settings.slotDurationMinutes = max(settings.slotDurationMinutes, 5)
        settings.defaultCapacity = max(settings.defaultCapacity, 1)
        settings.daysAhead = max(settings.daysAhead, 1)
        settings.leadTimeMinutes = max(settings.leadTimeMinutes, 0)

        if settings.allowAsap == false {
            settings.earliestPickupTimeText = ""
        }

        print("💾 Saving settings:")
        print("⏱ slotDurationMinutes:", settings.slotDurationMinutes)
        print("📦 defaultCapacity:", settings.defaultCapacity)
        print("📅 daysAhead:", settings.daysAhead)
        print("⏳ leadTimeMinutes:", settings.leadTimeMinutes)
        print("⚡ allowAsap:", settings.allowAsap)
        print("📝 earliestPickupTimeText:", settings.earliestPickupTimeText)

        do {
            try await service.updateSettings(settings)

            print("✅ Settings saved")

            let refreshedSettings = try await service.fetchSettings(profileId: profileId)

            print("🔄 Refreshed settings after save")
            print("⏱ refreshed slotDurationMinutes:", refreshedSettings.slotDurationMinutes)
            print("📦 refreshed defaultCapacity:", refreshedSettings.defaultCapacity)
            print("📅 refreshed daysAhead:", refreshedSettings.daysAhead)
            print("⚡ refreshed allowAsap:", refreshedSettings.allowAsap)

            self.settings = refreshedSettings
            successMessage = "Ustawienia zapisane"

            await loadDateOverride()
            await loadSlots()
        } catch {
            print("❌ saveSettings ERROR:", error)
            print("❌ localized:", error.localizedDescription)

            errorMessage = "Nie udało się zapisać ustawień: \(error.localizedDescription)"
        }
    }

    func saveDateOverride() async {
        print("🟠 saveDateOverride START")
        print("🚪 isClosed:", dateOverrideDraft.isClosed)
        print("🕘 openDate:", dateOverrideDraft.openDate)
        print("🕙 closeDate:", dateOverrideDraft.closeDate)
        print("📦 capacityOverride:", dateOverrideDraft.capacityOverride)
        print("📝 note:", dateOverrideDraft.note)

        errorMessage = nil
        successMessage = nil

        if !dateOverrideDraft.isClosed && dateOverrideDraft.openDate >= dateOverrideDraft.closeDate {
            print("⚠️ Invalid day hours: openDate >= closeDate")
            errorMessage = "Godzina otwarcia musi być wcześniejsza niż godzina zamknięcia"
            return
        }

        do {
            try await service.upsertDateOverride(
                profileId: profileId,
                date: selectedDate,
                fulfillmentType: selectedFulfillmentType,
                draft: dateOverrideDraft
            )

            print("✅ Date override saved")

            successMessage = "Zmiany dla dnia zapisane"
            await loadDateOverride()
            await loadSlots()
        } catch {
            print("❌ saveDateOverride ERROR:", error)
            print("❌ localized:", error.localizedDescription)

            errorMessage = "Nie udało się zapisać zmian dla dnia: \(error.localizedDescription)"
        }

        print("🟢 saveDateOverride END")
    }

    func clearDateOverride() async {
        print("🟠 clearDateOverride START")
        print("📅 selectedDate:", selectedDate)
        print("📦 fulfillmentType:", selectedFulfillmentType)

        errorMessage = nil
        successMessage = nil

        do {
            try await service.deleteDateOverride(
                profileId: profileId,
                date: selectedDate,
                fulfillmentType: selectedFulfillmentType
            )

            print("✅ Date override deleted")

            dateOverrideDraft = .empty
            successMessage = "Przywrócono bazowy harmonogram dnia"

            await loadDateOverride()
            await loadSlots()
        } catch {
            print("❌ clearDateOverride ERROR:", error)
            print("❌ localized:", error.localizedDescription)

            errorMessage = "Nie udało się usunąć zmian dla dnia: \(error.localizedDescription)"
        }

        print("🟢 clearDateOverride END")
    }

    func toggleBlocked(for slot: AdminDaySlot, blocked: Bool) async {
        print("🟠 toggleBlocked START")
        print("🆔 profileId:", profileId)
        print("📅 selectedDate:", selectedDate)
        print("📦 fulfillmentType:", selectedFulfillmentType)
        print("🕒 slotLabel:", slot.slotLabel)
        print("🔒 old isBlocked:", slot.isBlocked)
        print("➡️ new blocked:", blocked)
        print("📌 old status:", slot.status)
        print("🏷 old statusTitle:", slot.statusTitle)
        print("📦 capacity:", slot.capacity)
        print("📦 capacityOverrideValue:", String(describing: slot.capacityOverrideValue))
        print("🧾 taken:", slot.taken)
        print("🧾 remaining:", slot.remaining)

        errorMessage = nil
        successMessage = nil

        do {
            print("🚀 Calling service.setSlotBlocked...")

            try await service.setSlotBlocked(
                profileId: profileId,
                date: selectedDate,
                fulfillmentType: selectedFulfillmentType,
                slot: slot,
                blocked: blocked
            )

            print("✅ service.setSlotBlocked SUCCESS")

            successMessage = blocked ? "Slot zablokowany" : "Slot odblokowany"

            print("🔄 Reloading slots after block change...")
            await loadSlots()

            if let updatedSlot = adminSlots.first(where: { $0.slotLabel == slot.slotLabel }) {
                print("🔍 Updated slot found after reload")
                print("🕒 updated slotLabel:", updatedSlot.slotLabel)
                print("🔒 updated isBlocked:", updatedSlot.isBlocked)
                print("📌 updated status:", updatedSlot.status)
                print("🏷 updated statusTitle:", updatedSlot.statusTitle)
            } else {
                print("⚠️ Updated slot NOT found after reload")
            }

            print("🟢 toggleBlocked END")
        } catch {
            print("❌ toggleBlocked ERROR:", error)
            print("❌ localized:", error.localizedDescription)

            errorMessage = "Nie udało się zmienić statusu slotu: \(error.localizedDescription)"
        }
    }

    func saveCapacityOverride(for slot: AdminDaySlot, capacityText: String) async {
        print("🟠 saveCapacityOverride START")
        print("🕒 slotLabel:", slot.slotLabel)
        print("✏️ raw capacityText:", capacityText)

        errorMessage = nil
        successMessage = nil

        let trimmed = capacityText.trimmingCharacters(in: .whitespacesAndNewlines)

        print("✏️ trimmed capacityText:", trimmed)

        do {
            if trimmed.isEmpty {
                print("🧹 Removing capacity override")

                try await service.setSlotCapacityOverride(
                    profileId: profileId,
                    date: selectedDate,
                    fulfillmentType: selectedFulfillmentType,
                    slot: slot,
                    capacity: nil
                )

                print("✅ Capacity override removed")
                successMessage = "Usunięto limit dla slotu"
            } else if let capacity = Int(trimmed), capacity >= 1 {
                print("💾 Saving capacity override:", capacity)

                try await service.setSlotCapacityOverride(
                    profileId: profileId,
                    date: selectedDate,
                    fulfillmentType: selectedFulfillmentType,
                    slot: slot,
                    capacity: capacity
                )

                print("✅ Capacity override saved")
                successMessage = "Zapisano limit dla slotu"
            } else {
                print("⚠️ Invalid capacity value:", trimmed)
                errorMessage = "Podaj poprawną liczbę"
                return
            }

            print("🔄 Reloading slots after capacity change...")
            await loadSlots()
        } catch {
            print("❌ saveCapacityOverride ERROR:", error)
            print("❌ localized:", error.localizedDescription)

            errorMessage = "Nie udało się zapisać limitu dla slotu: \(error.localizedDescription)"
        }

        print("🟢 saveCapacityOverride END")
    }

    func currentCapacityText(for slot: AdminDaySlot) -> String {
        if let value = slot.capacityOverrideValue {
            return String(value)
        }

        return ""
    }

    func handleDateChanged() async {
        print("🟠 handleDateChanged")
        print("📅 selectedDate:", selectedDate)

        successMessage = nil
        errorMessage = nil

        await loadDateOverride()
        await loadSlots()
    }

    func handleFulfillmentChanged() async {
        print("🟠 handleFulfillmentChanged")
        print("📦 selectedFulfillmentType:", selectedFulfillmentType)

        successMessage = nil
        errorMessage = nil

        await loadDateOverride()
        await loadSlots()
    }

    private func draft(from override: SlotDateOverride, baseDate: Date) -> SlotDateOverrideDraft {
        print("🧾 Creating draft from date override")

        var draft = SlotDateOverrideDraft.empty
        draft.isClosed = override.isClosed

        if let openTime = override.openTime,
           let openDate = Self.timeDate(from: openTime, baseDate: baseDate) {
            draft.openDate = openDate
            print("🕘 draft openDate:", openDate)
        }

        if let closeTime = override.closeTime,
           let closeDate = Self.timeDate(from: closeTime, baseDate: baseDate) {
            draft.closeDate = closeDate
            print("🕙 draft closeDate:", closeDate)
        }

        // Не використовуємо денний capacity_override
        draft.capacityOverride = ""

        draft.note = override.note ?? ""

        return draft
    }

    private static func timeDate(from value: String, baseDate: Date) -> Date? {
        let pieces = value.split(separator: ":")

        guard pieces.count >= 2,
              let hour = Int(pieces[0]),
              let minute = Int(pieces[1]) else {
            print("⚠️ Cannot parse time:", value)
            return nil
        }

        return Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: baseDate
        )
    }
}
