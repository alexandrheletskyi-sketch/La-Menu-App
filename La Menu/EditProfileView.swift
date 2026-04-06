import SwiftUI
import UIKit
import Supabase
import PostgREST

struct EditProfileView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var accentHex: String = "#FF0043"
    @State private var selectedColor: Color = Color(red: 1, green: 0, blue: 67 / 255)
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

    var body: some View {
        NavigationStack {
            ZStack {
                pageBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
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
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                let normalized = normalizedHex(accentHex)
                accentHex = normalized
                selectedColor = colorFromHex(normalized)
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Edytuj profil")
                    .font(.custom("WixMadeforDisplay-Bold", size: 38))
                    .foregroundStyle(.black)

                Text("Tutaj możesz zmienić główny kolor swojej strony menu")
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

    private var colorPreviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Podgląd koloru")
                .font(.custom("WixMadeforDisplay-Bold", size: 22))
                .foregroundStyle(.black)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(selectedColor)
                .frame(height: 120)
                .overlay(
                    VStack(spacing: 10) {
                        Text("Twój kolor strony")
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
            Text("Wybierz dowolny kolor")
                .font(.custom("WixMadeforDisplay-Bold", size: 22))
                .foregroundStyle(.black)

            Text("Możesz wybrać dowolny kolor i od razu zobaczyć efekt")
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
            Text("Gotowe kolory")
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
            Text("Własny kolor")
                .font(.custom("WixMadeforDisplay-Bold", size: 22))
                .foregroundStyle(.black)

            Text("Wpisz kolor w formacie hex, na przykład #FF0043")
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
                    await saveAccentColor()
                }
            } label: {
                Text(isSaving ? "Zapisywanie..." : "Zapisz zmiany")
                    .font(.custom("WixMadeforDisplay-SemiBold", size: 18))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isSaving)

            Text("Po zapisaniu ten kolor będzie używany na stronie menu")
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

    private func saveAccentColor() async {
        let finalHex = normalizedHex(accentHex)

        guard let profileId = auth.profile?.id else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            try await SupabaseManager.shared
                .from("profiles")
                .update([
                    "accent_color": finalHex
                ])
                .eq("id", value: profileId.uuidString)
                .execute()

            dismiss()
        } catch {
            print("Save accent color error:", error)
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
