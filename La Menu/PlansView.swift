import SwiftUI

struct PlansView: View {
    @Environment(\.dismiss) private var dismiss

    let currentPlan: SubscriptionPlan
    let currentSmsCredits: Int

    private let accentOrange = Color(red: 1.0, green: 95.0 / 255.0, blue: 43.0 / 255.0)
    private let pageBackground = Color(red: 0.972, green: 0.972, blue: 0.972)
    private let cardBackground = Color.white
    private let mutedText = Color.black.opacity(0.58)
    private let secondaryText = Color.black.opacity(0.42)
    private let softBorder = Color.black.opacity(0.08)

    var body: some View {
        NavigationStack {
            ZStack {
                pageBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        heroSection

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Dostępne plany")
                                .font(.custom("WixMadeforDisplay-Bold", size: 30))
                                .foregroundStyle(.black)

                            ForEach(displayPlans, id: \.self) { plan in
                                planCard(plan)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white)

                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.black)
                        }
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(softBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                ToolbarItem(placement: .principal) {
                    Text("Plany")
                        .font(.custom("WixMadeforDisplay-SemiBold", size: 17))
                        .foregroundStyle(.black)
                }
            }
        }
    }

    private var displayPlans: [SubscriptionPlan] {
        [.free, .plus, .business, .premium]
    }

    private var recommendedPlan: SubscriptionPlan? {
        if currentPlan == .business {
            return nil
        }
        return .business
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Wybierz plan dla swojego lokalu")
                .font(.custom("WixMadeforDisplay-Bold", size: 38))
                .foregroundStyle(.black)
                .lineSpacing(-2)

            Text("Porównaj możliwości i wybierz plan najlepiej dopasowany do rozwoju Twojej sprzedaży")
                .font(.custom("WixMadeforDisplay-Regular", size: 16))
                .foregroundStyle(mutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 6)
    }

    private func planCard(_ plan: SubscriptionPlan) -> some View {
        let isCurrent = plan == currentPlan
        let isRecommended = recommendedPlan == plan

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                iconView(for: plan)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(title(for: plan))
                            .font(.custom("WixMadeforDisplay-Bold", size: 28))
                            .foregroundStyle(.black)

                        if isCurrent {
                            badge(
                                text: "Aktualny",
                                textColor: .white,
                                background: accentOrange
                            )
                        } else if isRecommended {
                            badge(
                                text: "Polecany",
                                textColor: accentOrange,
                                background: accentOrange.opacity(0.10)
                            )
                        }
                    }

                    Text(shortDescription(for: plan))
                        .font(.custom("WixMadeforDisplay-Regular", size: 15))
                        .foregroundStyle(mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            VStack(spacing: 12) {
                planRow(title: "Cena", value: priceText(for: plan))
                planRow(title: "Limit pozycji", value: menuLimitText(for: plan))
                planRow(title: "Pakiet SMS", value: smsCreditsText(for: plan))
            }

            if isCurrent {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accentOrange)

                    Text("Ten plan jest obecnie aktywny")
                        .font(.custom("WixMadeforDisplay-Medium", size: 14))
                        .foregroundStyle(.black.opacity(0.78))
                }
            } else {
                Button {
                    print("Wybrano plan: \(title(for: plan))")
                } label: {
                    HStack(spacing: 10) {
                        Text(isRecommended ? "Przejdź na ten plan" : "Wybierz plan")
                            .font(.custom("WixMadeforDisplay-SemiBold", size: 17))

                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(isRecommended ? .white : .black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isRecommended ? accentOrange : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(isRecommended ? accentOrange : softBorder, lineWidth: isRecommended ? 0 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(
                    isCurrent ? accentOrange.opacity(0.25) : softBorder,
                    lineWidth: isCurrent ? 1.4 : 1
                )
        )
    }

    private func planRow(title: String, value: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.custom("WixMadeforDisplay-Medium", size: 14))
                .foregroundStyle(secondaryText)

            Spacer()

            Text(value)
                .font(.custom("WixMadeforDisplay-SemiBold", size: 18))
                .foregroundStyle(.black)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 2)
    }

    private func badge(text: String, textColor: Color, background: Color) -> some View {
        Text(text)
            .font(.custom("WixMadeforDisplay-SemiBold", size: 12))
            .foregroundStyle(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(background)
            .clipShape(Capsule())
    }

    private func iconView(for plan: SubscriptionPlan) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(accentOrange.opacity(0.10))
                .frame(width: 56, height: 56)

            Image(systemName: iconName(for: plan))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(accentOrange)
        }
    }

    private func title(for plan: SubscriptionPlan) -> String {
        switch plan {
        case .free:
            return "Free"
        case .plus:
            return "Plus"
        case .business:
            return "Business"
        case .premium:
            return "Premium"
        }
    }

    private func shortDescription(for plan: SubscriptionPlan) -> String {
        switch plan {
        case .free:
            return "Na start dla małych lokali"
        case .plus:
            return "Więcej SMS i pełna swoboda menu"
        case .business:
            return "Dla rosnących lokali z większą liczbą zamówień"
        case .premium:
            return "Najwyższy pakiet dla najbardziej aktywnych lokali"
        }
    }

    private func priceText(for plan: SubscriptionPlan) -> String {
        switch plan {
        case .free:
            return "$0"
        case .plus:
            return "$29.99"
        case .business:
            return "$49.99"
        case .premium:
            return "$99.99"
        }
    }

    private func menuLimitText(for plan: SubscriptionPlan) -> String {
        switch plan {
        case .free:
            return "Do 20 pozycji"
        case .plus, .business, .premium:
            return "Nielimitowane"
        }
    }

    private func smsCreditsText(for plan: SubscriptionPlan) -> String {
        switch plan {
        case .free:
            return "20 SMS"
        case .plus:
            return "200 SMS"
        case .business:
            return "500 SMS"
        case .premium:
            return "1500 SMS"
        }
    }

    private func iconName(for plan: SubscriptionPlan) -> String {
        switch plan {
        case .free:
            return "sparkles"
        case .plus:
            return "circle.grid.2x2.fill"
        case .business:
            return "briefcase.fill"
        case .premium:
            return "crown.fill"
        }
    }
}

#Preview {
    NavigationStack {
        PlansView(
            currentPlan: .free,
            currentSmsCredits: 16
        )
    }
}
