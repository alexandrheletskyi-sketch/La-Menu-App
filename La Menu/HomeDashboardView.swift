import SwiftUI
import UIKit

struct HomeDashboardView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.openURL) private var openURL
    @State private var viewModel = HomeDashboardViewModel()

    private let pageBackground = Color.white
    private let cardBackground = Color.white
    private let softFill = Color.black.opacity(0.035)
    private let softBorder = Color.black.opacity(0.075)
    private let mutedText = Color.black.opacity(0.58)
    private let secondaryText = Color.black.opacity(0.42)
    private let accentOrange = Color(red: 1.0, green: 95.0 / 255.0, blue: 43.0 / 255.0)
    private let accentGreen = Color(red: 99.0 / 255.0, green: 225.0 / 255.0, blue: 141.0 / 255.0)

    var body: some View {
        NavigationStack {
            ZStack {
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
            }
            .toolbar(.hidden, for: .navigationBar)
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

            ordersToggleSection(profile: profile)

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
                    .fill(profile.isAcceptingOrders ? accentGreen : Color.black.opacity(0.18))
                    .frame(width: 7, height: 7)

                Text(profile.isAcceptingOrders ? "Otwarte na zamówienia" : "Zamówienia wstrzymane")
                    .font(.custom("WixMadeforDisplay-Medium", size: 14))
                    .foregroundStyle(.black.opacity(0.74))
                    .lineLimit(1)
            }
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

    private func ordersToggleSection(profile: Profile) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.04))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: profile.isAcceptingOrders ? "bolt.horizontal.fill" : "pause.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(profile.isAcceptingOrders ? accentOrange : .black.opacity(0.65))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("Przyjmowanie zamówień")
                    .font(.custom("WixMadeforDisplay-SemiBold", size: 19))
                    .foregroundStyle(.black)

                Text(
                    profile.isAcceptingOrders
                    ? "Klienci mogą teraz składać nowe zamówienia"
                    : "Nowe zamówienia są chwilowo wyłączone"
                )
                .font(.custom("WixMadeforDisplay-Regular", size: 13))
                .foregroundStyle(mutedText)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Toggle(
                "",
                isOn: Binding(
                    get: { profile.isAcceptingOrders },
                    set: { _ in
                        Task {
                            await viewModel.toggleAcceptingOrders()
                        }
                    }
                )
            )
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
}
