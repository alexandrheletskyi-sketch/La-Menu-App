import SwiftUI
import UIKit

struct HomeDashboardView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.openURL) private var openURL

    @State private var viewModel = HomeDashboardViewModel()
    @State private var showCopyToast = false
    @State private var showPlansView = false
    @State private var dashboardOrderFilter: DashboardOrderFilter = .today

    private let pageBackground = Color.white
    private let cardBackground = Color.white
    private let softBorder = Color.black.opacity(0.075)
    private let mutedText = Color.black.opacity(0.58)
    private let secondaryText = Color.black.opacity(0.42)

    private let accentOrange = Color(red: 1.0, green: 95.0 / 255.0, blue: 43.0 / 255.0)
    private let accentGreen = Color(red: 99.0 / 255.0, green: 225.0 / 255.0, blue: 141.0 / 255.0)
    private let accentYellow = Color(red: 1.0, green: 0.82, blue: 0.25)

    private let accentGreenText = Color(red: 0.12, green: 0.45, blue: 0.24)
    private let accentYellowText = Color(red: 0.55, green: 0.36, blue: 0.02)
    private let accentOrangeText = Color(red: 0.72, green: 0.30, blue: 0.02)

    enum DashboardOrderFilter: String, CaseIterable {
        case today
        case all

        var title: String {
            switch self {
            case .today:
                return "Dzisiaj"
            case .all:
                return "Wszystkie"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                pageBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    Group {
                        if viewModel.isLoading && viewModel.profile == nil {
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
                sectionHeader("Zamówienia")
                dashboardOrderFiltersSection
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
            .premiumCardStyle()
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
        HStack(spacing: 0) {
            androidStyleMetricBlock(
                emoji: "🛒",
                title: "Zamówienia",
                value: "\(viewModel.ordersTodayCount)"
            )

            Rectangle()
                .fill(Color.black.opacity(0.07))
                .frame(width: 1, height: 82)
                .padding(.horizontal, 10)

            androidStyleMetricBlock(
                emoji: "💵",
                title: "Przychód",
                value: "\(Int(viewModel.revenueToday)) zł"
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.black.opacity(0.075), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.025), radius: 10, x: 0, y: 3)
    }

    private func androidStyleMetricBlock(
        emoji: String,
        title: String,
        value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                Text(emoji)
                    .font(.system(size: 21))
                    .frame(width: 46, height: 46)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.black.opacity(0.055), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.035), radius: 8, x: 0, y: 3)

                Text(title)
                    .font(.custom("WixMadeforDisplay-Regular", size: 17))
                    .foregroundStyle(mutedText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Text(value)
                .font(.custom("WixMadeforDisplay-Bold", size: 38))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private var dashboardOrderFiltersSection: some View {
        HStack(spacing: 10) {
            dashboardOrderFilterPill(
                filter: .today,
                value: todayDashboardOrdersCount
            )

            dashboardOrderFilterPill(
                filter: .all,
                value: dashboardOrders.count
            )
        }
    }

    private func dashboardOrderFilterPill(
        filter: DashboardOrderFilter,
        value: Int
    ) -> some View {
        let isActive = dashboardOrderFilter == filter
        let activeBackground: Color = filter == .today ? accentOrange.opacity(0.22) : Color.black
        let activeForeground: Color = filter == .today ? accentOrangeText : .white

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                dashboardOrderFilter = filter
            }
        } label: {
            HStack(spacing: 7) {
                Text(filter.title)
                    .font(.custom("WixMadeforDisplay-Medium", size: 13))

                Text("\(value)")
                    .font(.custom("WixMadeforDisplay-SemiBold", size: 13))
            }
            .foregroundStyle(isActive ? activeForeground : .black.opacity(0.72))
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(isActive ? activeBackground : Color.black.opacity(0.035))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var recentOrdersSection: some View {
        VStack(spacing: 14) {
            if filteredDashboardOrders.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    emojiBubble("🧾", size: 52, fontSize: 23)

                    Text(dashboardEmptyTitle)
                        .font(.custom("WixMadeforDisplay-SemiBold", size: 22))
                        .foregroundStyle(.black)

                    Text(dashboardEmptySubtitle)
                        .font(.custom("WixMadeforDisplay-Regular", size: 15))
                        .foregroundStyle(mutedText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .premiumCardStyle()

            } else {
                ForEach(filteredDashboardOrders) { order in
                    dashboardOrderCard(order)
                }
            }
        }
    }

    private func dashboardOrderCard(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(order.customerName?.isEmpty == false ? order.customerName! : "Bez imienia")
                        .font(.custom("WixMadeforDisplay-Bold", size: 27))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(displayFulfillmentType(order.fulfillmentType))
                        .font(.custom("WixMadeforDisplay-Regular", size: 15))
                        .foregroundStyle(mutedText)

                    Text(formatOrderDate(order.createdAt))
                        .font(.custom("WixMadeforDisplay-Regular", size: 14))
                        .foregroundStyle(secondaryText)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 10) {
                    Text("\(Int(order.totalAmount)) zł")
                        .font(.custom("WixMadeforDisplay-Bold", size: 16))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(Color.black.opacity(0.045))
                        .clipShape(Capsule())

                    dashboardStatusBadge(order.status)
                }
            }

            Divider()
                .background(Color.black.opacity(0.06))

            VStack(spacing: 15) {
                let itemsText = viewModel.itemsText(for: order)

                if !itemsText.isEmpty {
                    dashboardOrderDetailRow(
                        emoji: "🛒",
                        title: "Produkty",
                        value: itemsText
                    )
                }

                if let phone = order.customerPhone, !phone.isEmpty {
                    dashboardOrderDetailRow(
                        emoji: "📞",
                        title: "Telefon",
                        value: phone
                    )
                }

                dashboardOrderDetailRow(
                    emoji: order.fulfillmentType == "pickup" ? "🏪" : "🚗",
                    title: "Sposób odbioru",
                    value: displayFulfillmentType(order.fulfillmentType)
                )

                if let pickupTime = order.pickupTime, !pickupTime.isEmpty {
                    dashboardOrderDetailRow(
                        emoji: "⏰",
                        title: "Godzina odbioru",
                        value: pickupTime
                    )
                }
            }

            Divider()
                .background(Color.black.opacity(0.06))

            VStack(alignment: .leading, spacing: 10) {
                Text("Zmień status")
                    .font(.custom("WixMadeforDisplay-Medium", size: 14))
                    .foregroundStyle(mutedText)

                HStack(spacing: 10) {
                    dashboardStatusActionButton(
                        title: "Nowe",
                        statusValue: "new",
                        currentStatus: order.status,
                        activeBackground: accentGreen,
                        activeForeground: .black
                    ) {
                        Task {
                            await updateDashboardOrderStatus(
                                orderID: order.id,
                                status: "new"
                            )
                        }
                    }

                    dashboardStatusActionButton(
                        title: "Przyjęte",
                        statusValue: "accepted",
                        currentStatus: order.status,
                        activeBackground: accentYellow,
                        activeForeground: .black
                    ) {
                        Task {
                            await updateDashboardOrderStatus(
                                orderID: order.id,
                                status: "accepted"
                            )
                        }
                    }

                    dashboardStatusActionButton(
                        title: "Gotowe",
                        statusValue: "ready",
                        currentStatus: order.status,
                        activeBackground: accentOrange,
                        activeForeground: .black
                    ) {
                        Task {
                            await updateDashboardOrderStatus(
                                orderID: order.id,
                                status: "ready"
                            )
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .premiumCardStyle()
    }

    private func dashboardStatusActionButton(
        title: String,
        statusValue: String,
        currentStatus: String,
        activeBackground: Color,
        activeForeground: Color,
        action: @escaping () -> Void
    ) -> some View {
        let isActive = currentStatus.lowercased() == statusValue.lowercased()

        return Button(action: action) {
            Text(title)
                .font(.custom("WixMadeforDisplay-SemiBold", size: 15))
                .foregroundStyle(isActive ? activeForeground : .black)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(isActive ? activeBackground : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isActive ? activeBackground : Color.black.opacity(0.10), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func dashboardOrderDetailRow(
        emoji: String,
        title: String,
        value: String
    ) -> some View {
        HStack(alignment: .top, spacing: 13) {
            emojiBubble(emoji)

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

    private func emojiBubble(
        _ emoji: String,
        size: CGFloat = 38,
        fontSize: CGFloat = 18
    ) -> some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(Color.white)
            .frame(width: size, height: size)
            .overlay(
                Text(emoji)
                    .font(.system(size: fontSize))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Color.black.opacity(0.055), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.025), radius: 6, x: 0, y: 2)
    }

    @ViewBuilder
    private func dashboardStatusBadge(_ status: String) -> some View {
        Text(displayStatus(status))
            .font(.custom("WixMadeforDisplay-SemiBold", size: 12))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(statusBackground(status))
            .foregroundStyle(statusForeground(status))
            .clipShape(Capsule())
    }

    private var dashboardOrders: [Order] {
        viewModel.recentOrders
    }

    private var filteredDashboardOrders: [Order] {
        switch dashboardOrderFilter {
        case .today:
            return dashboardOrders.filter { isTodayOrder($0) }

        case .all:
            return dashboardOrders
        }
    }

    private var todayDashboardOrdersCount: Int {
        dashboardOrders.filter { isTodayOrder($0) }.count
    }

    private var dashboardEmptyTitle: String {
        switch dashboardOrderFilter {
        case .today:
            return "Brak zamówień dzisiaj"

        case .all:
            return "Brak zamówień"
        }
    }

    private var dashboardEmptySubtitle: String {
        switch dashboardOrderFilter {
        case .today:
            return "Dzisiejsze zamówienia pojawią się tutaj automatycznie"

        case .all:
            return "Zamówienia pojawią się tutaj automatycznie"
        }
    }

    private func updateDashboardOrderStatus(orderID: UUID, status: String) async {
        await viewModel.updateStatus(orderID: orderID, status: status)
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

    private func isTodayOrder(_ order: Order) -> Bool {
        guard let date = parseOrderDate(order.createdAt) else {
            return false
        }

        return Calendar.current.isDateInToday(date)
    }

    private func displayFulfillmentType(_ type: String) -> String {
        type.lowercased() == "pickup" ? "Odbiór osobisty" : "Dostawa"
    }

    private func displayStatus(_ status: String) -> String {
        switch status.lowercased() {
        case "new":
            return "Nowe"
        case "accepted":
            return "Przyjęte"
        case "ready":
            return "Gotowe"
        case "done":
            return "Zakończone"
        default:
            return status
        }
    }

    private func statusBackground(_ status: String) -> Color {
        switch status.lowercased() {
        case "new":
            return accentGreen.opacity(0.22)
        case "accepted":
            return accentYellow.opacity(0.26)
        case "ready":
            return accentOrange.opacity(0.18)
        case "done":
            return Color.black.opacity(0.06)
        default:
            return Color.black.opacity(0.06)
        }
    }

    private func statusForeground(_ status: String) -> Color {
        switch status.lowercased() {
        case "new":
            return accentGreenText
        case "accepted":
            return accentYellowText
        case "ready":
            return accentOrangeText
        case "done":
            return Color.black.opacity(0.62)
        default:
            return Color.black.opacity(0.62)
        }
    }

    private func parseOrderDate(_ raw: String) -> Date? {
        let formatter1 = DateFormatter()
        formatter1.locale = Locale(identifier: "en_US_POSIX")
        formatter1.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX"

        let formatter2 = DateFormatter()
        formatter2.locale = Locale(identifier: "en_US_POSIX")
        formatter2.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"

        let formatter3 = DateFormatter()
        formatter3.locale = Locale(identifier: "en_US_POSIX")
        formatter3.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"

        return formatter1.date(from: raw)
            ?? formatter2.date(from: raw)
            ?? formatter3.date(from: raw)
    }

    private func formatOrderDate(_ raw: String) -> String {
        let output = DateFormatter()
        output.locale = Locale(identifier: "pl_PL")
        output.dateStyle = .medium
        output.timeStyle = .short

        if let date = parseOrderDate(raw) {
            return output.string(from: date)
        }

        return raw
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
