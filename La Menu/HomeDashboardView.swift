import SwiftUI
import UIKit

struct HomeDashboardView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.openURL) private var openURL

    @State private var viewModel = HomeDashboardViewModel()
    @State private var showCopyToast = false
    @State private var showPlansView = false

    private let pageBackground = Color.white
    private let cardBackground = Color.white
    private let softBorder = Color.black.opacity(0.075)
    private let mutedText = Color.black.opacity(0.58)
    private let secondaryText = Color.black.opacity(0.42)
    private let accentOrange = Color(red: 1.0, green: 95.0 / 255.0, blue: 43.0 / 255.0)
    private let accentGreen = Color(red: 99.0 / 255.0, green: 225.0 / 255.0, blue: 141.0 / 255.0)

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                pageBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    Group {
                        if viewModel.isLoading {
                            ProgressView("Ładowanie...")
                                .font(.custom("WixMadeforDisplay-Regular", size: 16))
                                .tint(.black)
                                .padding(.top, 80)

                        } else if let profile = viewModel.profile {
                            dashboardContent(profile: profile)

                        } else {
                            ContentUnavailableView(
                                "Brak profilu",
                                systemImage: "storefront",
                                description: Text("Najpierw uzupełnij onboarding")
                            )
                            .padding(.top, 80)
                        }
                    }
                }
                .background(Color.white)

                if showCopyToast {
                    copyToast
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 110)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showCopyToast)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showPlansView) {
                if let profile = viewModel.profile {
                    NavigationStack {
                        PlansView(
                            currentPlan: profile.subscriptionPlan,
                            currentSmsCredits: profile.currentSmsCredits ?? 0
                        )
                    }
                }
            }
            .task {
                guard let userId = auth.currentUserId else { return }
                await viewModel.load(for: userId)
            }
            .refreshable {
                guard let userId = auth.currentUserId else { return }
                await viewModel.load(for: userId)
            }
        }
    }

    private func dashboardContent(profile: Profile) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            headerSection(profile: profile)
            scheduleHeroCard(profile: profile)
            utilityRow(profile: profile)
            primaryActionsSection(profile: profile)

            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Dzisiaj")
                statsSection
            }

            ordersSettingsSection(profile: profile)

            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Ostatnie zamówienia")
                recentOrdersSection
            }

            seeAllButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 120)
    }

    private func headerSection(profile: Profile) -> some View {
        let addressText: String = {
            let value = profile.address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return value.isEmpty ? "Adres nie został dodany" : value
        }()

        return VStack(alignment: .leading, spacing: 14) {
            Text(profile.businessName)
                .font(.custom("WixMadeforDisplay-Bold", size: 42))
                .foregroundStyle(.black)
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            HStack(alignment: .center, spacing: 10) {
                Text(addressText)
                    .font(.custom("WixMadeforDisplay-Regular", size: 17))
                    .foregroundStyle(mutedText)
                    .lineLimit(1)

                Circle()
                    .fill(viewModel.isEffectivelyAcceptingOrders ? accentGreen : Color.black.opacity(0.18))
                    .frame(width: 7, height: 7)

                Text(viewModel.effectiveOrdersStatusTitle)
                    .font(.custom("WixMadeforDisplay-Medium", size: 14))
                    .foregroundStyle(.black.opacity(0.74))
                    .lineLimit(1)
            }

            Button {
                showPlansView = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accentOrange)

                    Text("Plan \(profile.subscriptionPlan.title)")
                        .font(.custom("WixMadeforDisplay-SemiBold", size: 14))
                        .foregroundStyle(.black)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.45))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.black.opacity(0.045))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func scheduleHeroCard(profile: Profile) -> some View {
        NavigationLink {
            SlotManagementView(profileId: profile.id)
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.045))
                    .frame(width: 54, height: 54)
                    .overlay(
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.black)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Zarządzaj rozkładem")
                        .font(.custom("WixMadeforDisplay-Bold", size: 22))
                        .foregroundStyle(.black)

                    Text("Godziny, sloty i limity zamówień")
                        .font(.custom("WixMadeforDisplay-Regular", size: 14))
                        .foregroundStyle(mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.04))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black)
                    )
            }
            .padding(18)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(softBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.02), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func utilityRow(profile: Profile) -> some View {
        let menuLink = "lamenu.pl/\(profile.username)"
        let menuURL = URL(string: "https://\(menuLink)")!

        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Publiczny link")
                    .font(.custom("WixMadeforDisplay-Medium", size: 12))
                    .foregroundStyle(secondaryText)

                Text(menuLink)
                    .font(.custom("WixMadeforDisplay-SemiBold", size: 17))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)

            Button {
                UIPasteboard.general.string = menuURL.absoluteString
                showCopiedFeedback()
            } label: {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.04))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.black)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 2)
    }

    private func primaryActionsSection(profile: Profile) -> some View {
        let menuURL = URL(string: "https://lamenu.pl/\(profile.username)")!

        return HStack(spacing: 12) {
            ShareLink(item: menuURL) {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .semibold))

                    Text("Udostępnij")
                        .font(.custom("WixMadeforDisplay-SemiBold", size: 18))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(softBorder, lineWidth: 1)
                )
            }

            Button {
                openURL(menuURL)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 17, weight: .semibold))

                    Text("Otwórz menu")
                        .font(.custom("WixMadeforDisplay-SemiBold", size: 18))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(accentOrange)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.custom("WixMadeforDisplay-Bold", size: 32))
            .foregroundStyle(.black)
    }

    private var statsSection: some View {
        HStack(spacing: 12) {
            statCard(
                title: "Zamówienia",
                value: "\(viewModel.ordersTodayCount)",
                icon: "cart"
            )

            statCard(
                title: "Przychód",
                value: "\(Int(viewModel.revenueToday)) zł",
                icon: "banknote"
            )
        }
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.035))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(title == "Przychód" ? accentOrange : .black)
                    )

                Spacer()

                Text("DZISIAJ")
                    .font(.custom("WixMadeforDisplay-Medium", size: 11))
                    .foregroundStyle(secondaryText)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.custom("WixMadeforDisplay-Regular", size: 16))
                    .foregroundStyle(mutedText)

                Text(value)
                    .font(.custom("WixMadeforDisplay-Bold", size: 35))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .premiumCardStyle()
    }

    private func ordersSettingsSection(profile: Profile) -> some View {
        VStack(spacing: 12) {
            settingToggleCard(
                title: "Przyjmowanie zamówień",
                subtitle: profile.isAcceptingOrders
                    ? "Klienci mogą składać zamówienia, jeśli lokal jest w godzinach pracy"
                    : "Nowe zamówienia są ręcznie wyłączone",
                systemImage: profile.isAcceptingOrders ? "bolt.horizontal.fill" : "pause.fill",
                iconColor: profile.isAcceptingOrders ? accentOrange : .black.opacity(0.65),
                isOn: Binding(
                    get: { profile.isAcceptingOrders },
                    set: { _ in
                        Task {
                            await viewModel.toggleAcceptingOrders()
                        }
                    }
                )
            )

            settingToggleCard(
                title: "Przedłuż przyjmowanie zamówień",
                subtitle: profile.continueAfterHours
                    ? "Lokal może przyjmować zamówienia także po godzinach pracy"
                    : "Po zamknięciu lokalu przyjmowanie zamówień zostanie zatrzymane",
                systemImage: profile.continueAfterHours ? "moon.stars.fill" : "moon.fill",
                iconColor: profile.continueAfterHours ? accentOrange : .black.opacity(0.65),
                isOn: Binding(
                    get: { profile.continueAfterHours },
                    set: { _ in
                        Task {
                            await viewModel.toggleContinueAfterHours()
                        }
                    }
                )
            )
        }
    }

    private func settingToggleCard(
        title: String,
        subtitle: String,
        systemImage: String,
        iconColor: Color,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.04))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(iconColor)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.custom("WixMadeforDisplay-SemiBold", size: 19))
                    .foregroundStyle(.black)

                Text(subtitle)
                    .font(.custom("WixMadeforDisplay-Regular", size: 13))
                    .foregroundStyle(mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(accentOrange)
        }
        .padding(18)
        .premiumCardStyle()
    }

    private var recentOrdersSection: some View {
        VStack(spacing: 14) {
            if viewModel.recentOrders.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Brak zamówień")
                        .font(.custom("WixMadeforDisplay-SemiBold", size: 19))
                        .foregroundStyle(.black)

                    Text("Nowe zamówienia pojawią się tutaj automatycznie")
                        .font(.custom("WixMadeforDisplay-Regular", size: 14))
                        .foregroundStyle(mutedText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .premiumCardStyle()

            } else {
                ForEach(viewModel.recentOrders) { order in
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Nowe zamówienie")
                                    .font(.custom("WixMadeforDisplay-Bold", size: 22))
                                    .foregroundStyle(.black)

                                Text(order.fulfillmentType == "pickup" ? "Odbiór osobisty" : "Dostawa")
                                    .font(.custom("WixMadeforDisplay-Regular", size: 14))
                                    .foregroundStyle(mutedText)
                            }

                            Spacer()

                            Text("\(Int(order.totalAmount)) zł")
                                .font(.custom("WixMadeforDisplay-SemiBold", size: 14))
                                .foregroundStyle(accentOrange)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(accentOrange.opacity(0.12))
                                .clipShape(Capsule())
                        }

                        Rectangle()
                            .fill(Color.black.opacity(0.06))
                            .frame(height: 1)

                        VStack(spacing: 14) {
                            orderDetailRow(
                                icon: "bag",
                                title: "Produkty",
                                value: viewModel.itemsText(for: order)
                            )

                            orderDetailRow(
                                icon: order.fulfillmentType == "pickup" ? "storefront" : "car",
                                title: "Sposób odbioru",
                                value: order.fulfillmentType == "pickup" ? "Odbiór osobisty" : "Dostawa"
                            )

                            if let pickupTime = order.pickupTime {
                                orderDetailRow(
                                    icon: "clock",
                                    title: "Godzina odbioru",
                                    value: pickupTime
                                )
                            }

                            if let phone = order.customerPhone {
                                orderDetailRow(
                                    icon: "phone",
                                    title: "Telefon",
                                    value: phone
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .premiumCardStyle()
                }
            }
        }
    }

    private func orderDetailRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.04))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.custom("WixMadeforDisplay-Medium", size: 13))
                    .foregroundStyle(secondaryText)

                Text(value)
                    .font(.custom("WixMadeforDisplay-SemiBold", size: 17))
                    .foregroundStyle(.black)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private var seeAllButton: some View {
        Button {
        } label: {
            HStack(spacing: 10) {
                Text("Wszystkie zamówienia")
                    .font(.custom("WixMadeforDisplay-SemiBold", size: 18))

                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(accentOrange)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }

    private var copyToast: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accentGreen)

            Text("Link skopiowany")
                .font(.custom("WixMadeforDisplay-SemiBold", size: 15))
                .foregroundStyle(.black)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 6)
    }

    private func showCopiedFeedback() {
        withAnimation {
            showCopyToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation {
                showCopyToast = false
            }
        }
    }
}

private struct PremiumCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.07), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.02), radius: 8, x: 0, y: 2)
    }
}

private extension View {
    func premiumCardStyle() -> some View {
        modifier(PremiumCardModifier())
    }
}

#Preview {
    HomeDashboardView()
        .environment(AuthViewModel())
}
