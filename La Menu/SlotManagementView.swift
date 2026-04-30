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
    private let strokeColor = Color.black.opacity(0.06)
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
                        VStack(alignment: .leading, spacing: 16) {
                            if let settings = viewModel.settings {
                                dateSection
                                slotsSection
                                settingsSection(settings: settings)
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
            print("📱 SlotManagementView .task -> load()")
            await viewModel.load()
        }
        .alert("Błąd", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(item: $capacityEditorSlot) { slot in
            SlotEditorSheet(
                slot: slot,
                capacityText: $capacityText,
                accentOrange: accentOrange,
                softFill: softFill,
                onSave: {
                    print("💾 SHEET: tapped Zapisz")
                    print("🕒 slot:", slot.slotLabel)
                    print("✏️ capacityText:", capacityText)

                    Task {
                        await viewModel.saveCapacityOverride(for: slot, capacityText: capacityText)
                        capacityEditorSlot = nil
                    }
                },
                onClear: {
                    print("🧹 SHEET: tapped Usuń limit")
                    print("🕒 slot:", slot.slotLabel)

                    Task {
                        capacityText = ""
                        await viewModel.saveCapacityOverride(for: slot, capacityText: "")
                        capacityEditorSlot = nil
                    }
                },
                onToggleBlocked: {
                    print("🔘 SHEET: tapped block/unblock button")
                    print("🕒 slot:", slot.slotLabel)
                    print("🔒 current slot.isBlocked:", slot.isBlocked)
                    print("➡️ new blocked value:", !slot.isBlocked)

                    Task {
                        await viewModel.toggleBlocked(for: slot, blocked: !slot.isBlocked)
                        capacityEditorSlot = nil
                    }
                }
            )
            .presentationDetents([.height(360)])
            .presentationDragIndicator(.visible)
        }
    }

    private var dateSection: some View {
        LMCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Dzień")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.availableDates, id: \.self) { date in
                            let isSelected = viewModel.selectedDate.isSameDay(as: date)

                            Button {
                                print("📅 Selected date:", date)

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

                Text(DateFormatter.polishFullDateTitle.string(from: viewModel.selectedDate).capitalized)
                    .font(.slotWix(14, weight: .medium))
                    .foregroundStyle(secondaryText)
            }
        }
    }

    private var slotsSection: some View {
        LMCard {
            VStack(alignment: .leading, spacing: 14) {
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
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Brak slotów")
                            .font(.slotWix(16, weight: .semiBold))
                            .foregroundStyle(.black)

                        Text("Sprawdź godziny tego dnia lub ustawienia slotów")
                            .font(.slotWix(13, weight: .regular))
                            .foregroundStyle(mutedText)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
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

    private func settingsSection(settings: VenueSlotSettings) -> some View {
        LMCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionTitle("Ustawienia")

                stepperRow(
                    title: "Długość slotu",
                    value: Binding(
                        get: { viewModel.settings?.slotDurationMinutes ?? 15 },
                        set: {
                            print("⏱ slotDurationMinutes changed:", $0)
                            viewModel.settings?.slotDurationMinutes = $0
                        }
                    ),
                    range: [5, 10, 15, 20, 30, 45, 60],
                    suffix: "min"
                )

                stepperRow(
                    title: "Limit domyślny",
                    value: Binding(
                        get: { viewModel.settings?.defaultCapacity ?? 3 },
                        set: {
                            print("📦 defaultCapacity changed:", $0)
                            viewModel.settings?.defaultCapacity = $0
                        }
                    ),
                    range: Array(1...20),
                    suffix: ""
                )

                LMToggleRow(
                    title: "Najszybszy odbiór",
                    subtitle: "",
                    isOn: Binding(
                        get: { viewModel.settings?.allowAsap ?? true },
                        set: {
                            print("⚡ allowAsap changed:", $0)
                            viewModel.settings?.allowAsap = $0
                        }
                    ),
                    tint: .green
                )

                Button {
                    print("💾 tapped Zapisz ustawienia")

                    Task {
                        await viewModel.saveSettings()

                        if viewModel.errorMessage == nil {
                            await viewModel.handleDateChanged()
                        }
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
                    .frame(height: 54)
                    .background(accentOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func slotRow(_ slot: AdminDaySlot) -> some View {
        Button {
            print("👆 tapped slot row")
            print("🕒 slotLabel:", slot.slotLabel)
            print("🔒 isBlocked:", slot.isBlocked)
            print("📌 status:", slot.status)
            print("📦 capacity:", slot.capacity)
            print("📦 capacityOverrideValue:", String(describing: slot.capacityOverrideValue))
            print("📦 hasCapacityOverride:", slot.hasCapacityOverride)
            print("🧾 taken:", slot.taken)
            print("🧾 remaining:", slot.remaining)

            capacityText = slot.capacityOverrideValue.map(String.init) ?? ""
            capacityEditorSlot = slot
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(slot.slotLabel)
                            .font(.slotWix(18, weight: .bold))
                            .foregroundStyle(.black)

                        if slot.hasCapacityOverride {
                            Text("Limit")
                                .font(.slotWix(11, weight: .semiBold))
                                .foregroundStyle(accentOrange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(accentOrangeSoft)
                                .clipShape(Capsule())
                        }
                    }

                    Text("\(slot.taken) / \(slot.capacity) zamówień")
                        .font(.slotWix(13, weight: .medium))
                        .foregroundStyle(.black.opacity(0.56))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text(slot.statusTitle)
                        .font(.slotWix(12, weight: .semiBold))
                        .foregroundStyle(statusForeground(for: slot.status))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(statusBackground(for: slot.status))
                        .clipShape(Capsule())

                    Text("Pozostało \(slot.remaining)")
                        .font(.slotWix(12, weight: .medium))
                        .foregroundStyle(.black.opacity(0.48))
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.24))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(softFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(strokeColor, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
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
                    .background(Color.black.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            Text("\(value.wrappedValue)\(suffix.isEmpty ? "" : " \(suffix)")")
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

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.slotWix(15, weight: .semiBold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(accentOrange)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.slotWix(15, weight: .semiBold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(softFill)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.slotWix(20, weight: .bold))
            .foregroundStyle(.black)
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
            return .black.opacity(0.62)
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

private struct SlotEditorSheet: View {
    let slot: AdminDaySlot
    @Binding var capacityText: String
    let accentOrange: Color
    let softFill: Color
    let onSave: () -> Void
    let onClear: () -> Void
    let onToggleBlocked: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(slot.slotLabel)
                    .font(.slotWix(24, weight: .bold))
                    .foregroundStyle(.black)

                Text("\(slot.taken) / \(slot.capacity) zamówień")
                    .font(.slotWix(14, weight: .medium))
                    .foregroundStyle(.black.opacity(0.56))
            }

            LMInputField(
                title: "Limit slotu",
                text: $capacityText,
                keyboard: .numberPad
            )

            Button(action: onToggleBlocked) {
                Text(slot.isBlocked ? "Odblokuj slot" : "Zablokuj slot")
                    .font(.slotWix(15, weight: .semiBold))
                    .foregroundStyle(slot.isBlocked ? .white : .black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(slot.isBlocked ? accentOrange : softFill)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)

            HStack(spacing: 12) {
                Button(action: onClear) {
                    Text("Usuń limit")
                        .font(.slotWix(15, weight: .semiBold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(softFill)
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

private extension Font {
    static func slotWix(_ size: CGFloat, weight: SlotWixWeight = .regular) -> Font {
        Font.custom(weight.fontName, size: size)
    }
}

private extension DateFormatter {
    static let polishFullDateTitle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter
    }()
}

private enum SlotWixWeight {
    case regular
    case medium
    case semiBold
    case bold
    case extraBold

    var fontName: String {
        switch self {
        case .regular:
            return "WixMadeforDisplay-Regular"
        case .medium:
            return "WixMadeforDisplay-Medium"
        case .semiBold:
            return "WixMadeforDisplay-SemiBold"
        case .bold:
            return "WixMadeforDisplay-Bold"
        case .extraBold:
            return "WixMadeforDisplay-ExtraBold"
        }
    }
}

private extension Date {
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
}
