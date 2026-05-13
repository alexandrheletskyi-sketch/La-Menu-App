import SwiftUI
import UIKit
import Supabase
import PostgREST

struct EditProfileView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var accentHex: String = "#FF0043"
    @State private var selectedColor: Color = Color(red: 1, green: 0, blue: 67 / 255)

    @State private var selectedLanguageCode: String = "pl"
    @State private var selectedCurrencyCode: String = "PLN"

    @State private var isLoading = false
    @State private var isSaving = false

    private let pageBackground = Color.white
    private let mutedText = Color.black.opacity(0.58)

    private let presetColors: [String] = [
        "#FF0043",
        "#FE592A",
        "#63E18D",
        "#111111",
        "#3B82F6",
        "#8B5CF6"
    ]

    private let languageOptions: [PublicLanguageOption] = [
        .init(code: "pl", title: "Polski", subtitle: "Język polski", flag: "🇵🇱"),
        .init(code: "en", title: "English", subtitle: "English language", flag: "🇬🇧")
    ]

    private let currencyOptions: [PublicCurrencyOption] = [
        .init(code: "PLN", title: "Polski złoty", subtitle: "zł", flag: "🇵🇱"),
        .init(code: "GBP", title: "British pound", subtitle: "£", flag: "🇬🇧"),
        .init(code: "EUR", title: "Euro", subtitle: "€", flag: "🇪🇺"),
        .init(code: "USD", title: "US dollar", subtitle: "$", flag: "🇺🇸")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                pageBackground
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(.black)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            headerSection
                            languageCard
                            currencyCard
                            colorPreviewCard
                            colorPickerCard
                            presetColorsCard
                            customHexCard
                            saveCard
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 40)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await loadProfileSettings()
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "Edytuj profil"))
                    .font(.custom("WixMadeforDisplay-Bold", size: 38))
                    .foregroundStyle(.black)

                Text(String(localized: "Tutaj możesz zmienić język, walutę i główny kolor swojej strony menu"))
                    .font(.custom("WixMadeforDisplay-Regular", size: 16))
                    .foregroundStyle(mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.05))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "Język strony"))
                .font(.custom("WixMadeforDisplay-Bold", size: 22))
                .foregroundStyle(.black)

            Text(String(localized: "Wybierz język, w którym będzie wyświetlana publiczna strona menu"))
                .font(.custom("WixMadeforDisplay-Regular", size: 14))
                .foregroundStyle(mutedText)

            VStack(spacing: 10) {
                ForEach(languageOptions) { option in
                    optionButton(
                        flag: option.flag,
                        title: option.title,
                        subtitle: option.subtitle,
                        isSelected: selectedLanguageCode == option.code
                    ) {
                        selectedLanguageCode = option.code
                    }
                }
            }
        }
        .padding(20)
        .editProfileCardStyle()
    }

    private var currencyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "Waluta strony"))
                .font(.custom("WixMadeforDisplay-Bold", size: 22))
                .foregroundStyle(.black)

            Text(String(localized: "Ta waluta będzie pokazywana przy cenach produktów i kosztach dostawy"))
                .font(.custom("WixMadeforDisplay-Regular", size: 14))
                .foregroundStyle(mutedText)

            VStack(spacing: 10) {
                ForEach(currencyOptions) { option in
                    optionButton(
                        flag: option.flag,
                        title: "\(option.title) · \(option.code)",
                        subtitle: option.subtitle,
                        isSelected: selectedCurrencyCode == option.code
                    ) {
                        selectedCurrencyCode = option.code
                    }
                }
            }
        }
        .padding(20)
        .editProfileCardStyle()
    }

    private func optionButton(
        flag: String,
        title: String,
        subtitle: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 14) {
                Text(flag)
                    .font(.system(size: 30))
                    .frame(width: 46, height: 46)
                    .background(Color.black.opacity(0.04))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.custom("WixMadeforDisplay-SemiBold", size: 17))
                        .foregroundStyle(.black)

                    Text(subtitle)
                        .font(.custom("WixMadeforDisplay-Regular", size: 13))
                        .foregroundStyle(mutedText)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? selectedColor : Color.black.opacity(0.18))
            }
            .padding(14)
            .background(isSelected ? selectedColor.opacity(0.10) : Color.black.opacity(0.035))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? selectedColor.opacity(0.45) : Color.black.opacity(0.06), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var colorPreviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "Podgląd koloru"))
                .font(.custom("WixMadeforDisplay-Bold", size: 22))
                .foregroundStyle(.black)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(selectedColor)
                .frame(height: 120)
                .overlay(
                    VStack(spacing: 10) {
                        Text(String(localized: "Twój kolor strony"))
                            .font(.custom("WixMadeforDisplay-Bold", size: 22))
                            .foregroundStyle(.white)

                        Text(normalizedHex(accentHex))
                            .font(.custom("WixMadeforDisplay-Medium", size: 14))
                            .foregroundStyle(.white.opacity(0.92))
                    }
                )
        }
        .padding(20)
        .editProfileCardStyle()
    }

    private var colorPickerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "Wybierz dowolny kolor"))
                .font(.custom("WixMadeforDisplay-Bold", size: 22))
                .foregroundStyle(.black)

            Text(String(localized: "Możesz wybrać dowolny kolor i od razu zobaczyć efekt"))
                .font(.custom("WixMadeforDisplay-Regular", size: 14))
                .foregroundStyle(mutedText)

            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selectedColor)
                    .frame(width: 68, height: 68)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )

                ColorPicker("", selection: colorBinding, supportsOpacity: false)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .editProfileCardStyle()
    }

    private var presetColorsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "Gotowe kolory"))
                .font(.custom("WixMadeforDisplay-Bold", size: 22))
                .foregroundStyle(.black)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                spacing: 12
            ) {
                ForEach(presetColors, id: \.self) { hex in
                    Button {
                        let normalized = normalizedHex(hex)
                        accentHex = normalized
                        selectedColor = colorFromHex(normalized)
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(colorFromHex(hex))
                                .frame(height: 74)

                            if normalizedHex(accentHex) == normalizedHex(hex) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Color.black.opacity(0.2))
                                    .clipShape(Circle())
                                    .padding(8)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .editProfileCardStyle()
    }

    private var customHexCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "Własny kolor"))
                .font(.custom("WixMadeforDisplay-Bold", size: 22))
                .foregroundStyle(.black)

            Text(String(localized: "Wpisz kolor w formacie hex, na przykład #FF0043"))
                .font(.custom("WixMadeforDisplay-Regular", size: 14))
                .foregroundStyle(mutedText)

            TextField("#FF0043", text: $accentHex)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.custom("WixMadeforDisplay-Medium", size: 17))
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(Color.black.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .onChange(of: accentHex) { _, newValue in
                    let sanitized = sanitizeHexInput(newValue)
                    if accentHex != sanitized {
                        accentHex = sanitized
                        return
                    }

                    let normalized = normalizedHex(sanitized)
                    selectedColor = colorFromHex(normalized)
                }
        }
        .padding(20)
        .editProfileCardStyle()
    }

    private var saveCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                Task {
                    await saveProfileSettings()
                }
            } label: {
                Text(isSaving ? String(localized: "Zapisywanie...") : String(localized: "Zapisz zmiany"))
                    .font(.custom("WixMadeforDisplay-SemiBold", size: 18))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isSaving)

            Text(String(localized: "Po zapisaniu ustawienia będą używane na publicznej stronie menu"))
                .font(.custom("WixMadeforDisplay-Regular", size: 13))
                .foregroundStyle(mutedText)
        }
        .padding(20)
        .editProfileCardStyle()
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: {
                selectedColor
            },
            set: { newColor in
                selectedColor = newColor
                accentHex = hexFromColor(newColor)
            }
        )
    }

    private func loadProfileSettings() async {
        guard let profileId = auth.profile?.id else {
            let normalized = normalizedHex(accentHex)
            accentHex = normalized
            selectedColor = colorFromHex(normalized)
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let response: PostgrestResponse<[EditProfileSettingsRow]> = try await SupabaseManager.shared
                .from("profiles")
                .select("accent_color, public_language, public_currency")
                .eq("id", value: profileId.uuidString)
                .limit(1)
                .execute()

            if let row = response.value.first {
                let loadedAccent = normalizedHex(row.accentColor ?? "#FF0043")
                accentHex = loadedAccent
                selectedColor = colorFromHex(loadedAccent)

                let loadedLanguage = String(row.publicLanguage ?? "pl").lowercased()
                selectedLanguageCode = languageOptions.contains(where: { $0.code == loadedLanguage }) ? loadedLanguage : "pl"

                let loadedCurrency = String(row.publicCurrency ?? "PLN").uppercased()
                selectedCurrencyCode = currencyOptions.contains(where: { $0.code == loadedCurrency }) ? loadedCurrency : "PLN"
            }
        } catch {
            print("Load profile settings error:", error)

            let normalized = normalizedHex(accentHex)
            accentHex = normalized
            selectedColor = colorFromHex(normalized)
        }
    }

    private func saveProfileSettings() async {
        let finalHex = normalizedHex(accentHex)
        let finalLanguage = selectedLanguageCode.lowercased()
        let finalCurrency = selectedCurrencyCode.uppercased()

        guard let profileId = auth.profile?.id else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            try await SupabaseManager.shared
                .from("profiles")
                .update([
                    "accent_color": finalHex,
                    "public_language": finalLanguage,
                    "public_currency": finalCurrency
                ])
                .eq("id", value: profileId.uuidString)
                .execute()

            dismiss()
        } catch {
            print("Save profile settings error:", error)
        }
    }

    private func sanitizeHexInput(_ value: String) -> String {
        let uppercased = value.uppercased()
        let filtered = uppercased.filter { char in
            char == "#" || char.isHexDigit
        }

        if filtered.hasPrefix("#") {
            return String(filtered.prefix(7))
        } else {
            return String(("#" + filtered).prefix(7))
        }
    }

    private func normalizedHex(_ value: String) -> String {
        let sanitized = sanitizeHexInput(value)
        if sanitized.count == 7 {
            return sanitized
        }
        return "#FF0043"
    }

    private func colorFromHex(_ hex: String) -> Color {
        let cleanHex = normalizedHex(hex).replacingOccurrences(of: "#", with: "")

        guard let int = UInt64(cleanHex, radix: 16) else {
            return Color(red: 1, green: 0, blue: 67 / 255)
        }

        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0

        return Color(red: r, green: g, blue: b)
    }

    private func hexFromColor(_ color: Color) -> String {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return "#FF0043"
        }

        let r = Int(round(red * 255))
        let g = Int(round(green * 255))
        let b = Int(round(blue * 255))

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

private struct PublicLanguageOption: Identifiable {
    let code: String
    let title: String
    let subtitle: String
    let flag: String

    var id: String { code }
}

private struct PublicCurrencyOption: Identifiable {
    let code: String
    let title: String
    let subtitle: String
    let flag: String

    var id: String { code }
}

private struct EditProfileSettingsRow: Decodable {
    let accentColor: String?
    let publicLanguage: String?
    let publicCurrency: String?

    enum CodingKeys: String, CodingKey {
        case accentColor = "accent_color"
        case publicLanguage = "public_language"
        case publicCurrency = "public_currency"
    }
}

private struct EditProfileCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.02), radius: 8, x: 0, y: 2)
    }
}

private extension View {
    func editProfileCardStyle() -> some View {
        modifier(EditProfileCardModifier())
    }
}
