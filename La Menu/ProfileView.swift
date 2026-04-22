import SwiftUI

struct ProfileView: View {
    @Environment(AuthViewModel.self) private var auth

    @State private var showEditProfile = false
    @State private var showSlotManagement = false
    @State private var showDeleteAccountAlert = false
    @State private var isDeletingAccount = false

    private let pageBackground = Color.white
    private let softFill = Color.black.opacity(0.04)
    private let mutedText = Color.black.opacity(0.58)
    private let secondaryText = Color.black.opacity(0.42)
    private let accentGreen = Color(red: 99 / 255, green: 225 / 255, blue: 141 / 255)
    private let accentGreenText = Color(red: 0.22, green: 0.58, blue: 0.34)
    private let accentOrange = Color(red: 1.0, green: 95.0 / 255.0, blue: 43.0 / 255.0)
    private let destructiveRed = Color.red.opacity(0.92)

    private var profileId: UUID? {
        auth.profile?.id
    }

    private var businessName: String {
        let value = auth.profile?.businessName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "Właściciel konta" : value
    }

    private var usernameText: String {
        if let username = auth.profile?.username, !username.isEmpty {
            return "lamenu.pl/\(username)"
        }
        return "Link nie został jeszcze ustawiony"
    }

    private var addressText: String {
        if let address = auth.profile?.address, !address.isEmpty {
            return address
        }
        return "Adres nie został jeszcze uzupełniony"
    }

    private var phoneText: String {
        if let phone = auth.profile?.phone, !phone.isEmpty {
            return phone
        }
        return "Telefon nie został jeszcze uzupełniony"
    }

    private var accountSubtitle: String {
        "Zarządzaj kontem, profilem lokalu i ustawieniami zamówień w jednym miejscu"
    }

    private var logoURL: URL? {
        guard let raw = auth.profile?.logoURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        return URL(string: raw)
    }

    private var businessInitial: String {
        let trimmed = businessName.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(1)).uppercased()
    }

    private var smsRemainingValue: Int {
        auth.profile?.smsCredits ?? 0
    }

    private var smsUsedValue: Int {
        if let value = auth.profile?.smsUsedThisMonth {
            return value
        }

        if let value = auth.profile?.smsUsedCurrentMonth {
            return value
        }

        return 0
    }

    private var smsRemainingText: String {
        "\(smsRemainingValue)"
    }

    private var smsUsedText: String {
        "\(smsUsedValue)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                pageBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        smsCard
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
                EditVenueProfileView()
                    .environment(auth)
            }
            .navigationDestination(isPresented: $showSlotManagement) {
                if let profileId {
                    SlotManagementView(profileId: profileId)
                }
            }
            .alert("Usunąć profil?", isPresented: $showDeleteAccountAlert) {
                Button("Anuluj", role: .cancel) { }

                Button("Usuń", role: .destructive) {
                    Task {
                        isDeletingAccount = true
                        defer { isDeletingAccount = false }
                        await auth.deleteAccount()
                    }
                }
            } message: {
                Text("Tej operacji nie można cofnąć. Wszystkie dane konta i lokalu zostaną usunięte.")
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

    private var smsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(accentOrange.opacity(0.12))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: "message.badge.waveform.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(accentOrange)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Powiadomienia SMS")
                        .font(.custom("WixMadeforDisplay-Bold", size: 22))
                        .foregroundStyle(.black)

                    Text("Dostępna liczba wiadomości SMS dla Twojego lokalu pobierana bezpośrednio z profilu")
                        .font(.custom("WixMadeforDisplay-Regular", size: 14))
                        .foregroundStyle(mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                smsMetricCard(
                    title: "Dostępne",
                    value: smsRemainingText,
                    highlight: true
                )

                smsMetricCard(
                    title: "Wykorzystane",
                    value: smsUsedText
                )
            }
        }
        .padding(20)
        .profileCardStyle()
    }

    private func smsMetricCard(
        title: String,
        value: String,
        highlight: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("WixMadeforDisplay-Medium", size: 13))
                .foregroundStyle(highlight ? accentGreenText : secondaryText)

            Text(value)
                .font(.custom("WixMadeforDisplay-Bold", size: 28))
                .foregroundStyle(.black)

            Text("SMS")
                .font(.custom("WixMadeforDisplay-Medium", size: 12))
                .foregroundStyle(mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(highlight ? accentGreen.opacity(0.14) : Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                profileLogoView

                VStack(alignment: .leading, spacing: 8) {
                    Text(businessName)
                        .font(.custom("WixMadeforDisplay-Bold", size: 28))
                        .foregroundStyle(.black)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Twoje konto jest aktualnie aktywne i gotowe do zarządzania lokalem")
                        .font(.custom("WixMadeforDisplay-Regular", size: 15))
                        .foregroundStyle(mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            VStack(spacing: 12) {
                profileInfoRow(
                    icon: "link",
                    title: "Link publiczny",
                    value: usernameText
                )

                profileInfoRow(
                    icon: "mappin.and.ellipse",
                    title: "Adres",
                    value: addressText
                )

                profileInfoRow(
                    icon: "phone",
                    title: "Telefon",
                    value: phoneText
                )
            }

            Text("La Menu Business")
                .font(.custom("WixMadeforDisplay-Medium", size: 13))
                .foregroundStyle(accentGreenText)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(accentGreen.opacity(0.18))
                .clipShape(Capsule())

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

    @ViewBuilder
    private var profileLogoView: some View {
        if let logoURL {
            AsyncImage(url: logoURL) { phase in
                switch phase {
                case .empty:
                    logoPlaceholder
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    logoPlaceholder
                @unknown default:
                    logoPlaceholder
                }
            }
            .frame(width: 78, height: 78)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
        } else {
            logoPlaceholder
                .frame(width: 78, height: 78)
        }
    }

    private var logoPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.05))

            if businessInitial.isEmpty || businessName == "Właściciel konta" {
                Image(systemName: "storefront.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.black)
            } else {
                Text(businessInitial)
                    .font(.custom("WixMadeforDisplay-Bold", size: 28))
                    .foregroundStyle(.black)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private func profileInfoRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(softFill)
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("WixMadeforDisplay-Medium", size: 13))
                    .foregroundStyle(secondaryText)

                Text(value)
                    .font(.custom("WixMadeforDisplay-SemiBold", size: 16))
                    .foregroundStyle(.black)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                    subtitle: "Nazwa, adres, telefon, link publiczny, dane prawne i wygląd",
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
                        .fixedSize(horizontal: false, vertical: true)
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

            Button {
                showDeleteAccountAlert = true
            } label: {
                HStack(spacing: 10) {
                    if isDeletingAccount {
                        ProgressView()
                            .tint(destructiveRed)
                    } else {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .semibold))
                    }

                    Text(isDeletingAccount ? "Usuwanie..." : "Usuń profil")
                        .font(.custom("WixMadeforDisplay-SemiBold", size: 18))
                }
                .foregroundStyle(destructiveRed)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(destructiveRed.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(destructiveRed.opacity(0.18), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isDeletingAccount)
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
