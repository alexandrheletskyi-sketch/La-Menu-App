import SwiftUI
import UIKit

struct SlotManagementView: View {
    @State private var viewModel: SlotManagementViewModel
    @State private var capacityEditorSlot: AdminDaySlot?
    @State private var capacityText: String = ""

    private let pageBackground = Color.white
    private let mutedText = Color.black.opacity(0.58)
    private let secondaryText = Color.black.opacity(0.42)

    init(profileId: UUID) {
        _viewModel = State(initialValue: SlotManagementViewModel(profileId: profileId))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                pageBackground
                    .ignoresSafeArea()

                if viewModel.isLoading && viewModel.settings == nil {
                    ProgressView()
                        .tint(.black)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            headerSection

                            if let settings = viewModel.settings {
                                settingsCard(settings: settings)
                                fulfillmentCard
                                dateSelectorCard
                                dayOverrideCard
                                slotsCard
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Sloty zamówień")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await viewModel.load()
        }
        .sheet(item: $capacityEditorSlot) { slot in
            SlotCapacityEditorSheet(
                slot: slot,
                capacityText: $capacityText,
                onSave: {
                    Task {
                        await viewModel.saveCapacityOverride(for: slot, capacityText: capacityText)
                        capacityEditorSlot = nil
                    }
                },
                onClear: {
                    Task {
                        capacityText = ""
                        await viewModel.saveCapacityOverride(for: slot, capacityText: "")
                        capacityEditorSlot = nil
                    }
                }
            )
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Zarządzaj oknami czasowymi i limitem zamówień dla każdego slotu")
                .font(.slotWix(14, weight: .regular))
                .foregroundStyle(mutedText)

            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                statusPill(text: errorMessage, color: .red)
            }

            if let successMessage = viewModel.successMessage, !successMessage.isEmpty {
                statusPill(text: successMessage, color: .green)
            }
        }
    }

    private func settingsCard(settings: VenueSlotSettings) -> some View {
        LMCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("Ustawienia ogólne")
                    .font(.slotWix(20, weight: .bold))
                    .foregroundStyle(.black)

                LMToggleRow(
                    title: "Sloty aktywne",
                    subtitle: "Po włączeniu klienci będą wybierać konkretną godzinę",
                    isOn: Binding(
                        get: { viewModel.settings?.slotsEnabled ?? false },
                        set: { viewModel.settings?.slotsEnabled = $0 }
                    )
                )

                VStack(spacing: 14) {
                    stepperRow(
                        title: "Długość slotu",
                        value: Binding(
                            get: { viewModel.settings?.slotDurationMinutes ?? 15 },
                            set: { viewModel.settings?.slotDurationMinutes = $0 }
                        ),
                        range: [5, 10, 15, 20, 30, 45, 60],
                        suffix: "min"
                    )

                    stepperRow(
                        title: "Limit na slot",
                        value: Binding(
                            get: { viewModel.settings?.defaultCapacity ?? 3 },
                            set: { viewModel.settings?.defaultCapacity = $0 }
                        ),
                        range: Array(1...20),
                        suffix: "zam."
                    )

                    stepperRow(
                        title: "Dni do przodu",
                        value: Binding(
                            get: { viewModel.settings?.daysAhead ?? 7 },
                            set: { viewModel.settings?.daysAhead = $0 }
                        ),
                        range: Array(1...30),
                        suffix: "dni"
                    )

                    stepperRow(
                        title: "Minimalny zapas czasu",
                        value: Binding(
                            get: { viewModel.settings?.leadTimeMinutes ?? 30 },
                            set: { viewModel.settings?.leadTimeMinutes = $0 }
                        ),
                        range: [0, 15, 30, 45, 60, 90, 120, 180],
                        suffix: "min"
                    )
                }

                LMToggleRow(
                    title: "Pozwól na ASAP",
                    subtitle: "Opcja na później, jeśli zechcesz dodać szybkie zamówienia bez wybranego slotu",
                    isOn: Binding(
                        get: { viewModel.settings?.allowAsap ?? true },
                        set: { viewModel.settings?.allowAsap = $0 }
                    )
                )

                Button {
                    Task {
                        await viewModel.saveSettings()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isSavingSettings {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.9)
                        }

                        Text(viewModel.isSavingSettings ? "Zapisywanie..." : "Zapisz ustawienia")
                            .font(.slotWix(16, weight: .semiBold))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    private var fulfillmentCard: some View {
        LMCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Typ realizacji")
                    .font(.slotWix(20, weight: .bold))
                    .foregroundStyle(.black)

                HStack(spacing: 10) {
                    ForEach(SlotFulfillmentType.allCases) { type in
                        Button {
                            guard viewModel.selectedFulfillmentType != type else { return }
                            viewModel.selectedFulfillmentType = type

                            Task {
                                await viewModel.handleFulfillmentChanged()
                            }
                        } label: {
                            Text(type.title)
                                .font(.slotWix(15, weight: .semiBold))
                                .foregroundStyle(viewModel.selectedFulfillmentType == type ? .white : .black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(viewModel.selectedFulfillmentType == type ? Color.black : Color.black.opacity(0.05))
                                )
                        }
                    }
                }
            }
        }
    }

    private var dateSelectorCard: some View {
        LMCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Dzień")
                    .font(.slotWix(20, weight: .bold))
                    .foregroundStyle(.black)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.availableDates, id: \.self) { date in
                            Button {
                                viewModel.selectedDate = date

                                Task {
                                    await viewModel.handleDateChanged()
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    Text(shortWeekday(date))
                                        .font(.slotWix(12, weight: .semiBold))
                                        .foregroundStyle(viewModel.selectedDate.isSameDay(as: date) ? .white.opacity(0.74) : .black.opacity(0.45))

                                    Text(dayNumber(date))
                                        .font(.slotWix(18, weight: .bold))
                                        .foregroundStyle(viewModel.selectedDate.isSameDay(as: date) ? .white : .black)
                                }
                                .frame(width: 64, height: 72)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(viewModel.selectedDate.isSameDay(as: date) ? Color.black : Color.black.opacity(0.05))
                                )
                            }
                        }
                    }
                }

                Text(DateFormatter.polishDayTitle.string(from: viewModel.selectedDate).capitalized)
                    .font(.slotWix(15, weight: .medium))
                    .foregroundStyle(secondaryText)
            }
        }
    }

    private var dayOverrideCard: some View {
        LMCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("Zmiany tylko dla wybranego dnia")
                    .font(.slotWix(20, weight: .bold))
                    .foregroundStyle(.black)

                LMToggleRow(
                    title: "Zamknij cały dzień",
                    subtitle: "Po włączeniu żaden slot nie będzie dostępny",
                    isOn: Binding(
                        get: { viewModel.dateOverrideDraft.isClosed },
                        set: { viewModel.dateOverrideDraft.isClosed = $0 }
                    )
                )

                if !viewModel.dateOverrideDraft.isClosed {
                    HStack(spacing: 12) {
                        LMTimePickerCard(
                            title: "Otwarcie",
                            date: Binding(
                                get: { viewModel.dateOverrideDraft.openDate },
                                set: { viewModel.dateOverrideDraft.openDate = $0 }
                            )
                        )

                        LMTimePickerCard(
                            title: "Zamknięcie",
                            date: Binding(
                                get: { viewModel.dateOverrideDraft.closeDate },
                                set: { viewModel.dateOverrideDraft.closeDate = $0 }
                            )
                        )
                    }

                    LMInputField(
                        title: "Limit dla całego dnia",
                        text: Binding(
                            get: { viewModel.dateOverrideDraft.capacityOverride },
                            set: { viewModel.dateOverrideDraft.capacityOverride = $0 }
                        ),
                        keyboard: .numberPad
                    )
                }

                LMInputField(
                    title: "Notatka",
                    text: Binding(
                        get: { viewModel.dateOverrideDraft.note },
                        set: { viewModel.dateOverrideDraft.note = $0 }
                    )
                )

                HStack(spacing: 12) {
                    Button {
                        Task {
                            await viewModel.clearDateOverride()
                        }
                    } label: {
                        Text("Usuń zmiany")
                            .font(.slotWix(15, weight: .semiBold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.black.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    Button {
                        Task {
                            await viewModel.saveDateOverride()
                        }
                    } label: {
                        Text("Zapisz dzień")
                            .font(.slotWix(15, weight: .semiBold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
        }
    }

    private var slotsCard: some View {
        LMCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Sloty")
                        .font(.slotWix(20, weight: .bold))
                        .foregroundStyle(.black)

                    Spacer()

                    if viewModel.isLoadingSlots {
                        ProgressView()
                            .tint(.black)
                            .scaleEffect(0.9)
                    }
                }

                if viewModel.adminSlots.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Brak slotów")
                            .font(.slotWix(16, weight: .semiBold))
                            .foregroundStyle(.black)

                        Text("Sprawdź harmonogram dnia lub ustawienia ogólne")
                            .font(.slotWix(14, weight: .regular))
                            .foregroundStyle(mutedText)
                    }
                    .padding(16)
                    .background(Color.black.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    VStack(spacing: 10) {
                        ForEach(viewModel.adminSlots) { slot in
                            slotRow(slot)
                        }
                    }
                }
            }
        }
    }

    private func slotRow(_ slot: AdminDaySlot) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(slot.slotLabel)
                            .font(.slotWix(18, weight: .bold))
                            .foregroundStyle(.black)

                        if slot.hasCapacityOverride {
                            Text("Override")
                                .font(.slotWix(11, weight: .semiBold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.black.opacity(0.08))
                                .clipShape(Capsule())
                        }
                    }

                    Text(slot.subtitle)
                        .font(.slotWix(13, weight: .regular))
                        .foregroundStyle(.black.opacity(0.52))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("Pozostało \(slot.remaining)")
                        .font(.slotWix(14, weight: .semiBold))
                        .foregroundStyle(.black)

                    Text(slot.statusTitle)
                        .font(.slotWix(12, weight: .semiBold))
                        .foregroundStyle(statusForeground(for: slot.status))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(statusBackground(for: slot.status))
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 10) {
                Button {
                    capacityText = slot.hasCapacityOverride ? "\(slot.capacity)" : ""
                    capacityEditorSlot = slot
                } label: {
                    Text("Limit slotu")
                        .font(.slotWix(14, weight: .semiBold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.black.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                if slot.isBlocked {
                    Button {
                        Task {
                            await viewModel.toggleBlocked(for: slot, blocked: false)
                        }
                    } label: {
                        Text("Odblokuj")
                            .font(.slotWix(14, weight: .semiBold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                } else {
                    Button {
                        Task {
                            await viewModel.toggleBlocked(for: slot, blocked: true)
                        }
                    } label: {
                        Text("Zablokuj")
                            .font(.slotWix(14, weight: .semiBold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.black.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func stepperRow(
        title: String,
        value: Binding<Int>,
        range: [Int],
        suffix: String
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.slotWix(15, weight: .medium))
                .foregroundStyle(.black)

            Spacer()

            Button {
                guard let currentIndex = range.firstIndex(of: value.wrappedValue),
                      currentIndex > 0 else { return }
                value.wrappedValue = range[currentIndex - 1]
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Text("\(value.wrappedValue) \(suffix)")
                .font(.slotWix(15, weight: .semiBold))
                .foregroundStyle(.black)
                .frame(minWidth: 72)

            Button {
                guard let currentIndex = range.firstIndex(of: value.wrappedValue),
                      currentIndex < range.count - 1 else { return }
                value.wrappedValue = range[currentIndex + 1]
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(14)
        .background(Color.black.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func statusPill(text: String, color: Color) -> some View {
        Text(text)
            .font(.slotWix(13, weight: .semiBold))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
    }

    private func shortWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).capitalized
    }

    private func dayNumber(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private func statusForeground(for status: String) -> Color {
        switch status {
        case "available":
            return .green
        case "blocked":
            return .red
        case "full":
            return .orange
        case "too_late":
            return Color.black.opacity(0.6)
        default:
            return .black
        }
    }

    private func statusBackground(for status: String) -> Color {
        switch status {
        case "available":
            return Color.green.opacity(0.10)
        case "blocked":
            return Color.red.opacity(0.10)
        case "full":
            return Color.orange.opacity(0.12)
        case "too_late":
            return Color.black.opacity(0.08)
        default:
            return Color.black.opacity(0.08)
        }
    }
}

private struct SlotCapacityEditorSheet: View {
    let slot: AdminDaySlot
    @Binding var capacityText: String
    let onSave: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Limit dla slotu \(slot.slotLabel)")
                .font(.slotWix(24, weight: .bold))
                .foregroundStyle(.black)

            Text("Zostaw puste, aby wrócić do domyślnego limitu")
                .font(.slotWix(14, weight: .regular))
                .foregroundStyle(.black.opacity(0.58))

            LMInputField(title: "Nowy limit", text: $capacityText, keyboard: .numberPad)

            HStack(spacing: 12) {
                Button(action: onClear) {
                    Text("Usuń limit")
                        .font(.slotWix(15, weight: .semiBold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.black.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                Button(action: onSave) {
                    Text("Zapisz")
                        .font(.slotWix(15, weight: .semiBold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }

            Spacer()
        }
        .padding(20)
        .background(Color.white)
    }
}

private struct LMCard<Content: View>: View {
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

private struct LMInputField: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.slotWix(13, weight: .medium))
                .foregroundStyle(.black.opacity(0.45))

            TextField(title, text: $text)
                .font(.slotWix(16, weight: .medium))
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

private struct LMToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.slotWix(16, weight: .semiBold))
                    .foregroundStyle(.black)

                Text(subtitle)
                    .font(.slotWix(13, weight: .regular))
                    .foregroundStyle(.black.opacity(0.52))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.black)
        }
        .padding(16)
        .background(Color.black.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct LMTimePickerCard: View {
    let title: String
    @Binding var date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.slotWix(13, weight: .medium))
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

private extension Font {
    static func slotWix(_ size: CGFloat, weight: SlotWixWeight = .regular) -> Font {
        Font.custom(weight.fontName, size: size)
    }
}

private enum SlotWixWeight {
    case regular
    case medium
    case semiBold
    case bold
    case extraBold

    var fontName: String {
        switch self {
        case .regular: return "WixMadeforDisplay-Regular"
        case .medium: return "WixMadeforDisplay-Medium"
        case .semiBold: return "WixMadeforDisplay-SemiBold"
        case .bold: return "WixMadeforDisplay-Bold"
        case .extraBold: return "WixMadeforDisplay-ExtraBold"
        }
    }
}

private extension Date {
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
}
