import SwiftUI
import Combine

struct OrdersView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var viewModel = OrdersViewModel()
    @State private var selectedFilter: OrderFilter = .today

    private let refreshTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    private let pageBackground = Color.white
    private let cardBackground = Color.white

    private let softFill = Color.black.opacity(0.035)
    private let softBorder = Color.black.opacity(0.08)
    private let mutedText = Color.black.opacity(0.56)
    private let secondaryText = Color.black.opacity(0.36)

    private let accentOrange = Color(red: 1.000, green: 0.557, blue: 0.176)
    private let accentGreen = Color(red: 99 / 255, green: 225 / 255, blue: 141 / 255)
    private let accentYellow = Color(red: 1.0, green: 0.82, blue: 0.25)

    private let accentGreenText = Color(red: 0.12, green: 0.45, blue: 0.24)
    private let accentYellowText = Color(red: 0.55, green: 0.36, blue: 0.02)
    private let accentOrangeText = Color(red: 0.72, green: 0.30, blue: 0.02)

    enum OrderFilter: String, CaseIterable {
        case today
        case all
        case new
        case ready

        var title: String {
            switch self {
            case .today:
                return "Dzisiaj"
            case .all:
                return "Wszystkie"
            case .new:
                return "Nowe"
            case .ready:
                return "Gotowe"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                pageBackground
                    .ignoresSafeArea()

                Group {
                    if let profileID = auth.profile?.id {
                        content(profileID: profileID)
                    } else {
                        ContentUnavailableView(
                            "Brak profilu",
                            systemImage: "cart.badge.questionmark",
                            description: Text("Nie udało się odczytać profilu")
                        )
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func content(profileID: UUID) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                headerSection

                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    errorCard(errorMessage)
                }

                if viewModel.isLoading && viewModel.orders.isEmpty {
                    loadingCard
                } else if filteredOrders.isEmpty {
                    emptyStateCard
                } else {
                    ordersListSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 120)
        }
        .background(Color.white)
        .task {
            await viewModel.load(profileID: profileID)
        }
        .refreshable {
            await viewModel.load(profileID: profileID)
        }
        .onReceive(refreshTimer) { _ in
            Task {
                await viewModel.load(profileID: profileID)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Zamówienia")
                    .font(.custom("WixMadeforDisplay-Bold", size: 44))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text("Monitoruj zamówienia, aktualizuj statusy i obsługuj klientów z jednego miejsca")
                    .font(.custom("WixMadeforDisplay-Regular", size: 17))
                    .foregroundStyle(mutedText)
                    .lineSpacing(2)
                    .frame(maxWidth: 350, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    filterPill(filter: .today, value: todayOrdersCount)
                    filterPill(filter: .all, value: viewModel.orders.count)
                    filterPill(filter: .new, value: newOrdersCount)
                    filterPill(filter: .ready, value: readyOrdersCount)

                    if viewModel.isLoading {
                        refreshPill
                    }
                }
            }
        }
    }

    private var refreshPill: some View {
        HStack(spacing: 7) {
            ProgressView()
                .scaleEffect(0.72)

            Text("Odświeżanie")
                .font(.custom("WixMadeforDisplay-Medium", size: 13))
        }
        .foregroundStyle(mutedText)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.black.opacity(0.035))
        .clipShape(Capsule())
    }

    private func filterPill(filter: OrderFilter, value: Int) -> some View {
        let isActive = selectedFilter == filter
        let activeBackground: Color = filter == .today ? accentOrange.opacity(0.22) : Color.black
        let activeForeground: Color = filter == .today ? accentOrangeText : .white

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedFilter = filter
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

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            emojiBubble("⚠️")

            VStack(alignment: .leading, spacing: 4) {
                Text("Wystąpił problem")
                    .font(.custom("WixMadeforDisplay-SemiBold", size: 17))
                    .foregroundStyle(.black)

                Text(message)
                    .font(.custom("WixMadeforDisplay-Regular", size: 14))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(18)
        .laMenuCardStyle()
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()

            Text("Ładowanie zamówień...")
                .font(.custom("WixMadeforDisplay-Regular", size: 16))
                .foregroundStyle(mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .laMenuCardStyle()
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            emojiBubble("🧾", size: 52, fontSize: 23)

            Text(emptyStateTitle)
                .font(.custom("WixMadeforDisplay-SemiBold", size: 22))
                .foregroundStyle(.black)

            Text(emptyStateSubtitle)
                .font(.custom("WixMadeforDisplay-Regular", size: 15))
                .foregroundStyle(mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .laMenuCardStyle()
    }

    private var ordersListSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(filteredOrders) { order in
                orderCard(order)
            }
        }
    }

    private func orderCard(_ order: Order) -> some View {
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

                    Text(formatHeaderDate(order.createdAt))
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

                    statusBadge(order.status)
                }
            }

            Divider()
                .background(Color.black.opacity(0.06))

            VStack(spacing: 15) {
                let itemsText = viewModel.itemsText(for: order)

                if !itemsText.isEmpty {
                    orderDetailRow(emoji: "🛒", title: "Produkty", value: itemsText)
                }

                if let phone = order.customerPhone, !phone.isEmpty {
                    orderDetailRow(emoji: "📞", title: "Telefon", value: phone)
                }

                orderDetailRow(
                    emoji: order.fulfillmentType == "pickup" ? "🏪" : "🚗",
                    title: "Sposób odbioru",
                    value: displayFulfillmentType(order.fulfillmentType)
                )

                if let pickupTime = order.pickupTime, !pickupTime.isEmpty {
                    orderDetailRow(emoji: "⏰", title: "Godzina odbioru", value: pickupTime)
                }
            }

            Divider()
                .background(Color.black.opacity(0.06))

            VStack(alignment: .leading, spacing: 10) {
                Text("Zmień status")
                    .font(.custom("WixMadeforDisplay-Medium", size: 14))
                    .foregroundStyle(mutedText)

                HStack(spacing: 10) {
                    statusActionButton(
                        title: "Nowe",
                        statusValue: "new",
                        currentStatus: order.status,
                        activeBackground: accentGreen,
                        activeForeground: .black
                    ) {
                        Task {
                            await viewModel.updateStatus(orderID: order.id, status: "new")
                        }
                    }

                    statusActionButton(
                        title: "Przyjęte",
                        statusValue: "accepted",
                        currentStatus: order.status,
                        activeBackground: accentYellow,
                        activeForeground: .black
                    ) {
                        Task {
                            await viewModel.updateStatus(orderID: order.id, status: "accepted")
                        }
                    }

                    statusActionButton(
                        title: "Gotowe",
                        statusValue: "ready",
                        currentStatus: order.status,
                        activeBackground: accentOrange,
                        activeForeground: .black
                    ) {
                        Task {
                            await viewModel.updateStatus(orderID: order.id, status: "ready")
                            selectedFilter = .ready
                        }
                    }
                }
            }
        }
        .padding(20)
        .laMenuCardStyle()
    }

    private func orderDetailRow(
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
            .fill(Color.black.opacity(0.035))
            .frame(width: size, height: size)
            .overlay(
                Text(emoji)
                    .font(.system(size: fontSize))
            )
    }

    private func statusActionButton(
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

    @ViewBuilder
    private func statusBadge(_ status: String) -> some View {
        Text(displayStatus(status))
            .font(.custom("WixMadeforDisplay-SemiBold", size: 12))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(statusBackground(status))
            .foregroundStyle(statusForeground(status))
            .clipShape(Capsule())
    }

    private var filteredOrders: [Order] {
        switch selectedFilter {
        case .today:
            return viewModel.orders.filter { isTodayOrder($0) }
        case .all:
            return viewModel.orders
        case .new:
            return viewModel.orders.filter { $0.status.lowercased() == "new" }
        case .ready:
            return viewModel.orders.filter { $0.status.lowercased() == "ready" }
        }
    }

    private var todayOrdersCount: Int {
        viewModel.orders.filter { isTodayOrder($0) }.count
    }

    private var newOrdersCount: Int {
        viewModel.orders.filter { $0.status.lowercased() == "new" }.count
    }

    private var readyOrdersCount: Int {
        viewModel.orders.filter { $0.status.lowercased() == "ready" }.count
    }

    private var emptyStateTitle: String {
        switch selectedFilter {
        case .today:
            return "Brak zamówień dzisiaj"
        case .all:
            return "Brak zamówień"
        case .new:
            return "Brak nowych zamówień"
        case .ready:
            return "Brak gotowych zamówień"
        }
    }

    private var emptyStateSubtitle: String {
        switch selectedFilter {
        case .today:
            return "Dzisiejsze zamówienia pojawią się tutaj automatycznie"
        case .all:
            return "Nowe zamówienia pojawią się tutaj automatycznie"
        case .new:
            return "Nowe zamówienia pojawią się tutaj, gdy klient złoży zamówienie"
        case .ready:
            return "Zamówienia oznaczone jako gotowe pojawią się tutaj"
        }
    }

    private func isTodayOrder(_ order: Order) -> Bool {
        guard let date = parseOrderDate(order.createdAt) else {
            return false
        }

        return Calendar.current.isDateInToday(date)
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

    private func formatHeaderDate(_ raw: String) -> String {
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

private struct LaMenuCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.075), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.025), radius: 12, x: 0, y: 5)
    }
}

private extension View {
    func laMenuCardStyle() -> some View {
        modifier(LaMenuCardModifier())
    }
}

#Preview {
    OrdersView()
}
