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
        isLoading = true
        errorMessage = nil
        successMessage = nil

        defer {
            isLoading = false
        }

        do {
            let fetchedSettings = try await service.fetchSettings(profileId: profileId)
            settings = fetchedSettings

            if !availableDates.contains(where: { Calendar.current.isDate($0, inSameDayAs: selectedDate) }) {
                selectedDate = Calendar.current.startOfDay(for: .now)
            }

            await loadDateOverride()
            await loadSlots()
        } catch {
            errorMessage = "Nie udało się wczytać ustawień slotów: \(error.localizedDescription)"
        }
    }

    func loadSlots() async {
        guard settings != nil else { return }

        isLoadingSlots = true
        errorMessage = nil

        defer {
            isLoadingSlots = false
        }

        do {
            adminSlots = try await service.fetchAdminDaySlots(
                profileId: profileId,
                date: selectedDate,
                fulfillmentType: selectedFulfillmentType
            )
        } catch {
            adminSlots = []
            errorMessage = "Nie udało się wczytać slotów: \(error.localizedDescription)"
        }
    }

    func loadDateOverride() async {
        do {
            if let override = try await service.fetchDateOverride(
                profileId: profileId,
                date: selectedDate,
                fulfillmentType: selectedFulfillmentType
            ) {
                dateOverrideDraft = draft(from: override, baseDate: selectedDate)
            } else {
                dateOverrideDraft = .empty
            }
        } catch {
            dateOverrideDraft = .empty
        }
    }

    func saveSettings() async {
        guard var settings else { return }

        isSavingSettings = true
        errorMessage = nil
        successMessage = nil

        defer {
            isSavingSettings = false
        }

        settings.slotDurationMinutes = max(settings.slotDurationMinutes, 5)
        settings.defaultCapacity = max(settings.defaultCapacity, 1)
        settings.daysAhead = max(settings.daysAhead, 1)
        settings.leadTimeMinutes = max(settings.leadTimeMinutes, 0)

        if settings.allowAsap == false {
            settings.earliestPickupTimeText = ""
        }

        do {
            try await service.updateSettings(settings)
            self.settings = settings
            successMessage = "Ustawienia zapisane"

            await loadDateOverride()
            await loadSlots()
        } catch {
            errorMessage = "Nie udało się zapisać ustawień: \(error.localizedDescription)"
        }
    }

    func saveDateOverride() async {
        errorMessage = nil
        successMessage = nil

        if !dateOverrideDraft.isClosed && dateOverrideDraft.openDate >= dateOverrideDraft.closeDate {
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

            successMessage = "Zmiany dla dnia zapisane"
            await loadDateOverride()
            await loadSlots()
        } catch {
            errorMessage = "Nie udało się zapisać zmian dla dnia: \(error.localizedDescription)"
        }
    }

    func clearDateOverride() async {
        errorMessage = nil
        successMessage = nil

        do {
            try await service.deleteDateOverride(
                profileId: profileId,
                date: selectedDate,
                fulfillmentType: selectedFulfillmentType
            )

            dateOverrideDraft = .empty
            successMessage = "Przywrócono bazowy harmonogram dnia"

            await loadDateOverride()
            await loadSlots()
        } catch {
            errorMessage = "Nie udało się usunąć zmian dla dnia: \(error.localizedDescription)"
        }
    }

    func toggleBlocked(for slot: AdminDaySlot, blocked: Bool) async {
        errorMessage = nil
        successMessage = nil

        do {
            try await service.setSlotBlocked(
                profileId: profileId,
                date: selectedDate,
                fulfillmentType: selectedFulfillmentType,
                slot: slot,
                blocked: blocked
            )

            successMessage = blocked ? "Slot zablokowany" : "Slot odblokowany"
            await loadSlots()
        } catch {
            errorMessage = "Nie udało się zmienić statusu slotu: \(error.localizedDescription)"
        }
    }

    func saveCapacityOverride(for slot: AdminDaySlot, capacityText: String) async {
        errorMessage = nil
        successMessage = nil

        let trimmed = capacityText.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            if trimmed.isEmpty {
                try await service.setSlotCapacityOverride(
                    profileId: profileId,
                    date: selectedDate,
                    fulfillmentType: selectedFulfillmentType,
                    slot: slot,
                    capacity: nil
                )
                successMessage = "Usunięto limit dla slotu"
            } else if let capacity = Int(trimmed), capacity >= 1 {
                try await service.setSlotCapacityOverride(
                    profileId: profileId,
                    date: selectedDate,
                    fulfillmentType: selectedFulfillmentType,
                    slot: slot,
                    capacity: capacity
                )
                successMessage = "Zapisano limit dla slotu"
            } else {
                errorMessage = "Podaj poprawną liczbę"
                return
            }

            await loadSlots()
        } catch {
            errorMessage = "Nie udało się zapisać limitu dla slotu: \(error.localizedDescription)"
        }
    }

    func currentCapacityText(for slot: AdminDaySlot) -> String {
        if let value = slot.capacityOverrideValue {
            return String(value)
        }
        return ""
    }

    func handleDateChanged() async {
        successMessage = nil
        errorMessage = nil
        await loadDateOverride()
        await loadSlots()
    }

    func handleFulfillmentChanged() async {
        successMessage = nil
        errorMessage = nil
        await loadDateOverride()
        await loadSlots()
    }

    private func draft(from override: SlotDateOverride, baseDate: Date) -> SlotDateOverrideDraft {
        var draft = SlotDateOverrideDraft.empty
        draft.isClosed = override.isClosed

        if let openTime = override.openTime,
           let openDate = Self.timeDate(from: openTime, baseDate: baseDate) {
            draft.openDate = openDate
        }

        if let closeTime = override.closeTime,
           let closeDate = Self.timeDate(from: closeTime, baseDate: baseDate) {
            draft.closeDate = closeDate
        }

        if let capacityOverride = override.capacityOverride {
            draft.capacityOverride = String(capacityOverride)
        } else {
            draft.capacityOverride = ""
        }

        draft.note = override.note ?? ""
        return draft
    }

    private static func timeDate(from value: String, baseDate: Date) -> Date? {
        let pieces = value.split(separator: ":")

        guard pieces.count >= 2,
              let hour = Int(pieces[0]),
              let minute = Int(pieces[1]) else {
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
