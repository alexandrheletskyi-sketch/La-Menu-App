import SwiftUI

struct HomeDashboardView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.openURL) private var openURL
    @State private var viewModel = HomeDashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .padding(.top, 80)
                } else if let profile = viewModel.profile {
                    VStack(alignment: .leading, spacing: 18) {
                        topBusinessSection(profile: profile)
                        menuLinkSection(profile: profile)
                        actionButtonsSection(profile: profile)
                        ordersToggleSection(profile: profile)
                        statsSection
                        recentOrdersSection
                        seeAllButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                } else {
                    ContentUnavailableView(
                        "No business profile",
                        systemImage: "storefront",
                        description: Text("Complete onboarding first")
                    )
                    .padding(.top, 80)
                }
            }
            .background(Color(.systemGray6))
            .navigationBarHidden(true)
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

    private func topBusinessSection(profile: Profile) -> some View {
        HStack(alignment: .center, spacing: 14) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .frame(width: 96, height: 96)
                .overlay(
                    Image(systemName: "fork.knife.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.black)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(profile.businessName)
                    .font(.system(size: 26, weight: .bold))

                Text(profile.address ?? "No address")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func menuLinkSection(profile: Profile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Twoje menu:")
                .font(.system(size: 24, weight: .bold))

            Text("lamenu.pl/\(profile.username)")
                .font(.system(size: 22, weight: .medium))
        }
    }

    private func actionButtonsSection(profile: Profile) -> some View {
        let menuURL = URL(string: "https://lamenu.pl/\(profile.username)")!

        return HStack(spacing: 14) {
            ShareLink(item: menuURL) {
                Text("Udostępnij link")
                    .font(.system(size: 18, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }

            Button {
                openURL(menuURL)
            } label: {
                Text("Zobacz menu")
                    .font(.system(size: 18, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
    }

    private func ordersToggleSection(profile: Profile) -> some View {
        HStack {
            Text("Przyjmowanie zamówień")
                .font(.system(size: 18, weight: .semibold))

            Spacer()

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
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var statsSection: some View {
        HStack(spacing: 12) {
            dashboardStatCard(
                title: "Zamówienia dzisiaj:",
                value: "\(viewModel.ordersTodayCount)"
            )

            dashboardStatCard(
                title: "Przychód dzisiaj:",
                value: "\(Int(viewModel.revenueToday))zł"
            )
        }
    }

    private func dashboardStatCard(title: String, value: String) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.orange)

            Text(value)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.black)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var recentOrdersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("🧾 Ostatnie zamówienia")
                .font(.system(size: 22, weight: .bold))

            if viewModel.recentOrders.isEmpty {
                RoundedRectangle(cornerRadius: 26)
                    .fill(Color.white.opacity(0.7))
                    .frame(height: 120)
                    .overlay(
                        Text("Brak zamówień")
                            .foregroundStyle(.secondary)
                    )
            } else {
                VStack(spacing: 14) {
                    ForEach(viewModel.recentOrders) { order in
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("🛒 Zamówione produkty:")
                                    .font(.system(size: 18, weight: .semibold))

                                Text(viewModel.itemsText(for: order))
                                    .font(.system(size: 17, weight: .regular))
                            }

                            Text("💰 Suma: \(Int(order.totalAmount)) zł")
                                .font(.system(size: 18, weight: .medium))

                            Text(order.fulfillmentType == "pickup" ? "🏪 Odbiór osobisty" : "🚚 Dostawa")
                                .font(.system(size: 18, weight: .medium))

                            if let pickupTime = order.pickupTime {
                                Text("🕒 Godzina odbioru: \(pickupTime)")
                                    .font(.system(size: 18, weight: .medium))
                            }

                            if let phone = order.customerPhone {
                                Text("📞 Telefon: \(phone)")
                                    .font(.system(size: 18, weight: .medium))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(22)
                        .background(Color.white.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                    }
                }
            }
        }
    }

    private var seeAllButton: some View {
        HStack {
            Spacer()

            Button {
            } label: {
                Text("Zobacz wszystkie")
                    .font(.system(size: 20, weight: .bold))
                    .padding(.horizontal, 34)
                    .padding(.vertical, 16)
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .padding(.top, 6)
    }
}

#Preview {
    HomeDashboardView()
}
