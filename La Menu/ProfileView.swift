import SwiftUI

struct ProfileView: View {
    @Environment(AuthViewModel.self) private var auth

    @State private var showEditProfile = false
    @State private var showSlotManagement = false

    private let pageBackground = Color.white
    private let softFill = Color.black.opacity(0.04)
    private let mutedText = Color.black.opacity(0.58)
    private let secondaryText = Color.black.opacity(0.42)
    private let accentGreen = Color(red: 99 / 255, green: 225 / 255, blue: 141 / 255)
    private let accentGreenText = Color(red: 0.22, green: 0.58, blue: 0.34)

    private var profileId: UUID? {
        auth.profile?.id
    }

    private var businessName: String {
        auth.profile?.businessName ?? "Właściciel konta"
    }

    private var accountSubtitle: String {
        "Zarządzaj kontem, profilem lokalu i ustawieniami zamówień w jednym miejscu"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                pageBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        profileCard
                        toolsCard
                        signOutCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 120)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
                    .environment(auth)
            }
            .navigationDestination(isPresented: $showSlotManagement) {
                if let profileId {
                    SlotManagementView(profileId: profileId)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Profil")
                .font(.custom("WixMadeforDisplay-Bold", size: 44))
                .foregroundStyle(.black)

            Text(accountSubtitle)
                .font(.custom("WixMadeforDisplay-Regular", size: 17))
                .foregroundStyle(mutedText)
                .lineSpacing(2)
                .frame(maxWidth: 340, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                infoPill(
                    title: "Konto",
                    foreground: .black,
                    background: Color.black.opacity(0.06)
                )

                infoPill(
                    title: "Aktywne",
                    foreground: accentGreenText,
                    background: accentGreen.opacity(0.18)
                )
            }
        }
    }

    private func infoPill(title: String, foreground: Color, background: Color) -> some View {
        Text(title)
            .font(.custom("WixMadeforDisplay-Medium", size: 13))
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(background)
            .clipShape(Capsule())
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                Circle()
                    .fill(softFill)
                    .frame(width: 86, height: 86)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.black)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(businessName)
                        .font(.custom("WixMadeforDisplay-Bold", size: 27))
                        .foregroundStyle(.black)

                    Text("Twoje konto jest aktualnie aktywne")
                        .font(.custom("WixMadeforDisplay-Regular", size: 15))
                        .foregroundStyle(mutedText)

                    Text("La Menu Business")
                        .font(.custom("WixMadeforDisplay-Medium", size: 13))
                        .foregroundStyle(accentGreenText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(accentGreen.opacity(0.18))
                        .clipShape(Capsule())
                }

                Spacer(minLength: 0)
            }

            Button {
                showEditProfile = true
            } label: {
                actionButton(
                    icon: "slider.horizontal.3",
                    title: "Edytuj profil",
                    foreground: .black,
                    background: Color.black.opacity(0.05)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .profileCardStyle()
    }

    private var toolsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Narzędzia")
                .font(.custom("WixMadeforDisplay-Bold", size: 24))
                .foregroundStyle(.black)

            VStack(spacing: 12) {
                toolRow(
                    icon: "person.crop.circle",
                    title: "Edycja profilu",
                    subtitle: "Nazwa, opis, adres, telefon i wygląd",
                    action: {
                        showEditProfile = true
                    }
                )

                toolRow(
                    icon: "calendar.badge.clock",
                    title: "Zarządzaj slotami",
                    subtitle: "Godziny, limity i dostępność slotów zamówień",
                    isEnabled: profileId != nil,
                    action: {
                        if profileId != nil {
                            showSlotManagement = true
                        }
                    }
                )

                infoRow(
                    icon: "gearshape",
                    title: "Ustawienia",
                    subtitle: "Konfiguracja aplikacji i preferencji"
                )

                infoRow(
                    icon: "lock.shield",
                    title: "Bezpieczeństwo",
                    subtitle: "Bezpieczne korzystanie z konta"
                )
            }
        }
        .padding(20)
        .profileCardStyle()
    }

    private func toolRow(
        icon: String,
        title: String,
        subtitle: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(softFill)
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isEnabled ? .black : .black.opacity(0.35))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.custom("WixMadeforDisplay-SemiBold", size: 18))
                        .foregroundStyle(isEnabled ? .black : .black.opacity(0.35))

                    Text(subtitle)
                        .font(.custom("WixMadeforDisplay-Regular", size: 14))
                        .foregroundStyle(isEnabled ? mutedText : mutedText.opacity(0.7))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.35))
            }
            .padding(16)
            .background(Color.black.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.65)
    }

    private func infoRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(softFill)
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.custom("WixMadeforDisplay-SemiBold", size: 18))
                    .foregroundStyle(.black)

                Text(subtitle)
                    .font(.custom("WixMadeforDisplay-Regular", size: 14))
                    .foregroundStyle(mutedText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.black.opacity(0.35))
        }
        .padding(16)
        .background(Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var signOutCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(softFill)
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.black)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Zakończ sesję")
                        .font(.custom("WixMadeforDisplay-SemiBold", size: 20))
                        .foregroundStyle(.black)

                    Text("Wyloguj się, jeśli chcesz bezpiecznie zakończyć pracę w aplikacji")
                        .font(.custom("WixMadeforDisplay-Regular", size: 14))
                        .foregroundStyle(mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            Button {
                Task {
                    await auth.signOut()
                }
            } label: {
                Text("Wyloguj się")
                    .font(.custom("WixMadeforDisplay-SemiBold", size: 18))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .profileCardStyle()
    }

    private func actionButton(
        icon: String,
        title: String,
        foreground: Color,
        background: Color
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))

            Text(title)
                .font(.custom("WixMadeforDisplay-SemiBold", size: 17))
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct ProfileCardModifier: ViewModifier {
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

extension View {
    func profileCardStyle() -> some View {
        modifier(ProfileCardModifier())
    }
}

#Preview {
    ProfileView()
}
