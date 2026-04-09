import SwiftUI
import UIKit

struct SlotManagementView: View {
    @State private var viewModel: SlotManagementViewModel
    @State private var capacityEditorSlot: AdminDaySlot?
    @State private var capacityText: String = ""

    private let pageBackground = Color.white
    private let mutedText = Color.black.opacity(0.58)
    private let secondaryText = Color.black.opacity(0.42)
    private let softFill = Color.black.opacity(0.04)
    private let accentOrange = Color(red: 1.0, green: 95.0 / 255.0, blue: 43.0 / 255.0)
    private let accentOrangeSoft = Color(red: 1.0, green: 95.0 / 255.0, blue: 43.0 / 255.0).opacity(0.12)

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
                                dateSelectorCard
                                dayOverrideCard
                                slotsCard
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 36)
                    }
                }
            }
            .navigationTitle("Rozkład zamówień")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await viewModel.load()
        }
        .sheet(item: $capacityEditorSlot) { slot in
            SlotCapacityEditorSheet(
                slot: slot,
                capacityText: $capacityText,
                accentOrange: accentOrange,
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
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ustaw godziny, sloty, limity i najszybszy możliwy czas odbioru dla klientów")
                .font(.slotWix(15, weight: .regular))
                .foregroundStyle(mutedText)
                .fixedSize(horizontal: false, vertical: true)

            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                statusPill(text: errorMessage, foreground: .red, background: .red.opacity(0.10))
            }

            if let successMessage = viewModel.successMessage, !successMessage.isEmpty {
                statusPill(text: successMessage, foreground: accentOrange, background: accentOrangeSoft)
            }
        }
    }

    private func settingsCard(settings: VenueSlotSettings) -> some View {
        LMCard {
            VStack(alignment: .leading, spacing: 18) {
                sectionTitle("Ustawienia ogólne")

                LMToggleRow(
                    title: "Pozwól na najszybszy odbiór",
                    subtitle: "Klient będzie mógł wybrać najszybszy dostępny termin bez wskazywania konkretnej godziny",
                    isOn: Binding(
                        get: { viewModel.settings?.allowAsap ?? true },
                        set: { viewModel.settings?.allowAsap = $0 }
                    ),
                    accentColor: .green
                )

                VStack(spacing: 12) {
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

                if settings.allowAsap {
                    LMInputField(
                        title: "Najszybszy możliwy odbiór",
                        subtitle: "Np. 20–25 min lub 30 min. Ten tekst będzie wyświetlany klientowi przy zamówieniu",
                        text: Binding(
                            get: { viewModel.settings?.earliestPickupTimeText ?? "" },
                            set: { viewModel.settings?.earliestPickupTimeText = $0 }
                        )
                    )
                }

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
                    .background(accentOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var dateSelectorCard: some View {
        LMCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionTitle("Dzień")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.availableDates, id: \.self) { date in
                            let isSelected = viewModel.selectedDate.isSameDay(as: date)

                            Button {
                                Task {
                                    viewModel.selectedDate = date
                                    await viewModel.handleDateChanged()
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    Text(shortWeekday(date))
                                        .font(.slotWix(12, weight: .semiBold))
                                        .foregroundStyle(isSelected ? .white.opacity(0.78) : .black.opacity(0.45))

                                    Text(dayNumber(date))
                                        .font(.slotWix(19, weight: .bold))
                                        .foregroundStyle(isSelected ? .white : .black)
                                }
                                .frame(width: 66, height: 74)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(isSelected ? accentOrange : softFill)
                                )
                            }
                            .buttonStyle(.plain)
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
                sectionTitle("Zmiany dla wybranego dnia")

                LMToggleRow(
                    title: "Zamknij cały dzień",
                    subtitle: "Po włączeniu wszystkie sloty dla tego dnia będą niedostępne",
                    isOn: Binding(
                        get: { viewModel.dateOverrideDraft.isClosed },
                        set: { viewModel.dateOverrideDraft.isClosed = $0 }
                    ),
                    accentColor: .green
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
                        subtitle: "Opcjonalnie. Jeśli puste, zostaną użyte standardowe limity",
                        text: Binding(
                            get: { viewModel.dateOverrideDraft.capacityOverride },
                            set: { viewModel.dateOverrideDraft.capacityOverride = $0 }
                        ),
                        keyboard: .numberPad
                    )
                }

                LMInputField(
                    title: "Notatka",
                    subtitle: "Wewnętrzna informacja dla tego dnia",
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
                            .background(softFill)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)

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
                            .background(accentOrange)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var slotsCard: some View {
        LMCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    sectionTitle("Sloty")

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

                        Text("Sprawdź harmonogram dnia albo ustawienia ogólne")
                            .font(.slotWix(14, weight: .regular))
                            .foregroundStyle(mutedText)
                    }
                    .padding(16)
                    .background(softFill)
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
                                .foregroundStyle(accentOrange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(accentOrangeSoft)
                                .clipShape(Capsule())
                        }
                    }

                    Text(slot.subtitle)
                        .font(.slotWix(13, weight: .regular))
                        .foregroundStyle(.black.opacity(0.52))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("Zajęte \(slot.taken)/\(slot.capacity)")
                        .font(.slotWix(14, weight: .semiBold))
                        .foregroundStyle(.black)

                    Text("Pozostało \(slot.remaining)")
                        .font(.slotWix(12, weight: .medium))
                        .foregroundStyle(.black.opacity(0.58))

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
                    capacityText = slot.capacityOverrideValue.map(String.init) ?? ""
                    capacityEditorSlot = slot
                } label: {
                    Text("Limit slotu")
                        .font(.slotWix(14, weight: .semiBold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(softFill)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

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
                            .frame(height: 46)
                            .background(accentOrange)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
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
                            .frame(height: 46)
                            .background(softFill)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(softFill)
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
                    .frame(width: 38, height: 38)
                    .background(softFill)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            Text("\(value.wrappedValue) \(suffix)")
                .font(.slotWix(15, weight: .semiBold))
                .foregroundStyle(.black)
                .frame(minWidth: 78)

            Button {
                guard let currentIndex = range.firstIndex(of: value.wrappedValue),
                      currentIndex < range.count - 1 else { return }
                value.wrappedValue = range[currentIndex + 1]
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(accentOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(softFill)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.slotWix(20, weight: .bold))
            .foregroundStyle(.black)
    }

    private func statusPill(text: String, foreground: Color, background: Color) -> some View {
        Text(text)
            .font(.slotWix(13, weight: .semiBold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(background)
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
            return accentOrange
        case "blocked":
            return .red
        case "full":
            return .orange
        case "too_late":
            return Color.black.opacity(0.62)
        default:
            return .black
        }
    }

    private func statusBackground(for status: String) -> Color {
        switch status {
        case "available":
            return accentOrangeSoft
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
    let accentOrange: Color
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

            LMInputField(
                title: "Nowy limit",
                subtitle: nil,
                text: $capacityText,
                keyboard: .numberPad
            )

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
                .buttonStyle(.plain)

                Button(action: onSave) {
                    Text("Zapisz")
                        .font(.slotWix(15, weight: .semiBold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(accentOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
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
            .shadow(color: .black.opacity(0.02), radius: 8, x: 0, y: 2)
    }
}

private struct LMInputField: View {
    let title: String
    let subtitle: String?
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.slotWix(13, weight: .medium))
                .foregroundStyle(.black.opacity(0.45))

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.slotWix(12, weight: .regular))
                    .foregroundStyle(.black.opacity(0.46))
                    .fixedSize(horizontal: false, vertical: true)
            }

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
    let accentColor: Color

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
                .tint(accentColor)
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
