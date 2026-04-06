import SwiftUI
import Combine

struct OrdersView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var viewModel = OrdersViewModel()

    private let refreshTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    private let pageBackground = Color(red: 0.965, green: 0.965, blue: 0.965)
    private let cardBackground = Color.white
    private let softFill = Color.black.opacity(0.04)
    private let softBorder = Color.black.opacity(0.08)
    private let mutedText = Color.black.opacity(0.58)
    private let accentOrange = Color(red: 1.000, green: 0.557, blue: 0.176)
    private let accentGreen = Color(red: 99/255, green: 225/255, blue: 141/255)
    private let accentGreenText = Color(red: 0.22, green: 0.58, blue: 0.34)
    private let accentBlue = Color(red: 0.86, green: 0.93, blue: 1.00)
    private let accentBlueText = Color(red: 0.12, green: 0.52, blue: 0.96)

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
            VStack(alignment: .leading, spacing: 24) {
                headerSection

                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    errorCard(errorMessage)
                }

                if viewModel.isLoading && viewModel.orders.isEmpty {
                    loadingCard
                } else if viewModel.orders.isEmpty {
                    emptyStateCard
                } else {
                    ordersListSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 120)
        }
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
        VStack(alignment: .leading, spacing: 16) {
            Text("Zamówienia")
                .font(.custom("WixMadeforDisplay-Bold", size: 44))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text("Monitoruj nowe zamówienia, aktualizuj ich status i miej wszystko pod kontrolą")
                .font(.custom("WixMadeforDisplay-Regular", size: 17))
                .foregroundStyle(mutedText)
                .lineSpacing(2)
                .frame(maxWidth: 320, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                summaryPill(
                    title: "Wszystkie",
                    value: viewModel.orders.count,
                    foreground: accentBlueText,
                    background: accentBlue
                )

                summaryPill(
                    title: "Nowe",
                    value: newOrdersCount,
                    foreground: accentBlueText,
                    background: accentBlue
                )

                if viewModel.isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)

                        Text("Odświeżanie")
                            .font(.custom("WixMadeforDisplay-Medium", size: 13))
                    }
                    .foregroundStyle(mutedText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.05))
                    .clipShape(Capsule())
                }
            }
        }
    }

    private func summaryPill(title: String, value: Int, foreground: Color, background: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.custom("WixMadeforDisplay-Medium", size: 13))

            Text("\(value)")
                .font(.custom("WixMadeforDisplay-SemiBold", size: 13))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(background)
        .clipShape(Capsule())
    }

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.red.opacity(0.10))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.red)
                )

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
        .uberCardStyle()
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
        .uberCardStyle()
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(softFill)
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: "tray")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.black)
                )

            Text("Brak zamówień")
                .font(.custom("WixMadeforDisplay-SemiBold", size: 22))
                .foregroundStyle(.black)

            Text("Nowe zamówienia pojawią się tutaj automatycznie")
                .font(.custom("WixMadeforDisplay-Regular", size: 15))
                .foregroundStyle(mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .uberCardStyle()
    }

    private var ordersListSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(viewModel.orders) { order in
                orderCard(order)
            }
        }
    }

    private func orderCard(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(order.customerName?.isEmpty == false ? order.customerName! : "Bez imienia")
                        .font(.custom("WixMadeforDisplay-Bold", size: 26))
                        .foregroundStyle(.black)

                    Text(displayFulfillmentType(order.fulfillmentType))
                        .font(.custom("WixMadeforDisplay-Regular", size: 15))
                        .foregroundStyle(mutedText)

                    Text(formatHeaderDate(order.createdAt))
                        .font(.custom("WixMadeforDisplay-Regular", size: 14))
                        .foregroundStyle(mutedText)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 10) {
                    Text("\(Int(order.totalAmount)) zł")
                        .font(.custom("WixMadeforDisplay-SemiBold", size: 15))
                        .foregroundStyle(accentGreenText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(accentGreen.opacity(0.18))
                        .clipShape(Capsule())

                    statusBadge(order.status)
                }
            }

            Rectangle()
                .fill(Color.black.opacity(0.07))
                .frame(height: 1)

            VStack(spacing: 14) {
                let itemsText = viewModel.itemsText(for: order)
                if !itemsText.isEmpty {
                    orderDetailRow(
                        icon: "bag",
                        title: "Produkty",
                        value: itemsText
                    )
                }

                if let phone = order.customerPhone, !phone.isEmpty {
                    orderDetailRow(
                        icon: "phone",
                        title: "Telefon",
                        value: phone
                    )
                }

                orderDetailRow(
                    icon: order.fulfillmentType == "pickup" ? "storefront" : "car",
                    title: "Sposób odbioru",
                    value: displayFulfillmentType(order.fulfillmentType)
                )

                if let pickupTime = order.pickupTime, !pickupTime.isEmpty {
                    orderDetailRow(
                        icon: "clock",
                        title: "Godzina odbioru",
                        value: pickupTime
                    )
                }
            }

            Rectangle()
                .fill(Color.black.opacity(0.07))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 10) {
                Text("Zmień status")
                    .font(.custom("WixMadeforDisplay-Medium", size: 14))
                    .foregroundStyle(mutedText)

                HStack(spacing: 10) {
                    statusActionButton(
                        title: "Nowe",
                        statusValue: "new",
                        currentStatus: order.status,
                        isProminent: false
                    ) {
                        Task {
                            await viewModel.updateStatus(orderID: order.id, status: "new")
                        }
                    }

                    statusActionButton(
                        title: "Przyjęte",
                        statusValue: "accepted",
                        currentStatus: order.status,
                        isProminent: false
                    ) {
                        Task {
                            await viewModel.updateStatus(orderID: order.id, status: "accepted")
                        }
                    }

                    statusActionButton(
                        title: "Gotowe",
                        statusValue: "ready",
                        currentStatus: order.status,
                        isProminent: true
                    ) {
                        Task {
                            await viewModel.updateStatus(orderID: order.id, status: "ready")
                        }
                    }
                }
            }
        }
        .padding(20)
        .uberCardStyle()
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

    private func statusActionButton(
        title: String,
        statusValue: String,
        currentStatus: String,
        isProminent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let isActive = currentStatus.lowercased() == statusValue.lowercased()

        return Button(action: action) {
            Text(title)
                .font(.custom("WixMadeforDisplay-SemiBold", size: 15))
                .foregroundStyle(buttonForeground(isActive: isActive, isProminent: isProminent))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(buttonBackground(isActive: isActive, isProminent: isProminent))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(buttonBorder(isActive: isActive, isProminent: isProminent), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func buttonForeground(isActive: Bool, isProminent: Bool) -> Color {
        if isActive && isProminent {
            return .black
        }
        if isActive {
            return .white
        }
        return .black
    }

    private func buttonBackground(isActive: Bool, isProminent: Bool) -> Color {
        if isActive {
            return isProminent ? accentGreen : .black
        }
        return .white
    }

    private func buttonBorder(isActive: Bool, isProminent: Bool) -> Color {
        if isActive {
            return isProminent ? accentGreen : .black
        }
        return Color.black.opacity(0.08)
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

    private var newOrdersCount: Int {
        viewModel.orders.filter { $0.status.lowercased() == "new" }.count
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
            return accentBlue
        case "accepted":
            return accentOrange.opacity(0.14)
        case "ready":
            return accentGreen.opacity(0.18)
        case "done":
            return Color.black.opacity(0.08)
        default:
            return Color.black.opacity(0.08)
        }
    }

    private func statusForeground(_ status: String) -> Color {
        switch status.lowercased() {
        case "new":
            return accentBlueText
        case "accepted":
            return accentOrange
        case "ready":
            return accentGreenText
        case "done":
            return Color.black.opacity(0.65)
        default:
            return Color.black.opacity(0.65)
        }
    }

    private func formatHeaderDate(_ raw: String) -> String {
        let formatter1 = DateFormatter()
        formatter1.locale = Locale(identifier: "en_US_POSIX")
        formatter1.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX"

        let formatter2 = DateFormatter()
        formatter2.locale = Locale(identifier: "en_US_POSIX")
        formatter2.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"

        let output = DateFormatter()
        output.locale = Locale(identifier: "pl_PL")
        output.dateStyle = .medium
        output.timeStyle = .short

        if let date = formatter1.date(from: raw) ?? formatter2.date(from: raw) {
            return output.string(from: date)
        }

        return raw
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
    OrdersView()
}
