import SwiftUI
import UIKit

struct HomeDashboardView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.openURL) private var openURL
    @State private var viewModel = HomeDashboardViewModel()

    private let pageBackground = Color(red: 0.965, green: 0.965, blue: 0.965)
    private let cardBackground = Color.white
    private let softFill = Color.black.opacity(0.04)
    private let softBorder = Color.black.opacity(0.08)
    private let mutedText = Color.black.opacity(0.58)
    private let accentOrange = Color(red: 1.000, green: 0.557, blue: 0.176)
    private let accentGreen = Color(red: 0.110, green: 0.620, blue: 0.290)

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
            actionButtonsSection(profile: profile)

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

        let menuLink = "lamenu.pl/\(profile.username)"

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(profile.businessName)
                        .font(.custom("WixMadeforDisplay-Bold", size: 39))
                        .foregroundStyle(.black)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text(addressText)
                        .font(.custom("WixMadeforDisplay-Regular", size: 16))
                        .foregroundStyle(mutedText)
                        .lineLimit(2)

                    statusBadge(isOn: profile.isAcceptingOrders)
                        .padding(.top, 2)
                }

                Spacer(minLength: 12)

                businessLogoView(profile: profile)
            }

            openLinkRow(menuLink: menuLink)
        }
    }

    private func openLinkRow(menuLink: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Publiczny link")
                .font(.custom("WixMadeforDisplay-Medium", size: 13))
                .foregroundStyle(mutedText)

            HStack(spacing: 12) {
                Text(menuLink)
                    .font(.custom("WixMadeforDisplay-SemiBold", size: 20))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 0)

                Button {
                    UIPasteboard.general.string = "https://\(menuLink)"
                } label: {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(softFill)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.black)
                        )
                }
                .buttonStyle(.plain)
            }

            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1)
                .padding(.top, 2)
        }
    }

    @ViewBuilder
    private func businessLogoView(profile: Profile) -> some View {
        let logo = profile.logoURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if let url = URL(string: logo), !logo.isEmpty {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                logoPlaceholder
            }
            .frame(width: 112, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        } else {
            logoPlaceholder
        }
    }

    private var logoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(cardBackground)
            .frame(width: 112, height: 112)
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(softBorder, lineWidth: 1)
            )
            .overlay(
                Image(systemName: "fork.knife")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.black)
            )
    }

    private func statusBadge(isOn: Bool) -> some View {
        Text(isOn ? "Przyjmujesz zamówienia" : "Zamówienia wstrzymane")
            .font(.custom("WixMadeforDisplay-Medium", size: 12))
            .foregroundStyle(
                isOn ? accentGreen : Color.black.opacity(0.68)
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isOn
                ? accentGreen.opacity(0.12)
                : Color.black.opacity(0.06)
            )
            .clipShape(Capsule())
    }

    private func actionButtonsSection(profile: Profile) -> some View {
        let menuURL = URL(string: "https://lamenu.pl/\(profile.username)")!

        return HStack(spacing: 12) {
            ShareLink(item: menuURL) {
                Label("Udostępnij", systemImage: "square.and.arrow.up")
                    .font(.custom("WixMadeforDisplay-SemiBold", size: 17))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(softBorder, lineWidth: 1)
                    )
            }

            Button {
                openURL(menuURL)
            } label: {
                Label("Otwórz menu", systemImage: "arrow.up.right")
                    .font(.custom("WixMadeforDisplay-SemiBold", size: 17))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                subtitle: "DZISIAJ",
                value: "\(viewModel.ordersTodayCount)",
                icon: "cart"
            )

            statCard(
                title: "Przychód",
                subtitle: "DZISIAJ",
                value: "\(Int(viewModel.revenueToday)) zł",
                icon: "banknote"
            )
        }
    }

    private func statCard(title: String, subtitle: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(softFill)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(title == "Przychód" ? accentOrange : .black)
                    )

                Spacer()

                Text(subtitle)
                    .font(.custom("WixMadeforDisplay-Medium", size: 11))
                    .foregroundStyle(mutedText)
            }

            Text(title)
                .font(.custom("WixMadeforDisplay-Regular", size: 16))
                .foregroundStyle(mutedText)

            Text(value)
                .font(.custom("WixMadeforDisplay-Bold", size: 34))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .uberCardStyle()
    }

    private func ordersToggleSection(profile: Profile) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(softFill)
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: "bolt.horizontal")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("Przyjmowanie zamówień")
                    .font(.custom("WixMadeforDisplay-SemiBold", size: 19))
                    .foregroundStyle(.black)

                Text(
                    profile.isAcceptingOrders
                    ? "Klienci mogą teraz składać nowe zamówienia"
                    : "Nowe zamówienia są chwilowo wyłączone"
                )
                .font(.custom("WixMadeforDisplay-Regular", size: 14))
                .foregroundStyle(mutedText)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

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
            .tint(Color.black)
        }
        .padding(18)
        .uberCardStyle()
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
                .uberCardStyle()

            } else {
                ForEach(viewModel.recentOrders) { order in
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Nowe zamówienie")
                                    .font(.custom("WixMadeforDisplay-Bold", size: 24))
                                    .foregroundStyle(.black)

                                Text(order.fulfillmentType == "pickup" ? "Odbiór osobisty" : "Dostawa")
                                    .font(.custom("WixMadeforDisplay-Regular", size: 15))
                                    .foregroundStyle(mutedText)
                            }

                            Spacer()

                            Text("\(Int(order.totalAmount)) zł")
                                .font(.custom("WixMadeforDisplay-SemiBold", size: 15))
                                .foregroundStyle(accentGreen)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(accentGreen.opacity(0.12))
                                .clipShape(Capsule())
                        }

                        Rectangle()
                            .fill(Color.black.opacity(0.07))
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
                    .uberCardStyle()
                }
            }
        }
    }

    private func orderDetailRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(softFill)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.custom("WixMadeforDisplay-Medium", size: 13))
                    .foregroundStyle(mutedText)

                Text(value)
                    .font(.custom("WixMadeforDisplay-SemiBold", size: 18))
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
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }
}

private struct UberCardModifier: ViewModifier {
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
    func uberCardStyle() -> some View {
        modifier(UberCardModifier())
    }
}

#Preview {
    HomeDashboardView()
}
