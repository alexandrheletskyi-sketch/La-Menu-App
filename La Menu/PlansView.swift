import SwiftUI
import StoreKit
import Supabase

struct PlansView: View {
    @Environment(\.dismiss) private var dismiss

    let profileId: UUID
    var onPlanPurchased: ((SubscriptionPlan) -> Void)? = nil

    @State private var activePlan: SubscriptionPlan
    @State private var activeSmsCredits: Int

    @State private var storeKitManager = StoreKitManager()

    @State private var purchasingPlan: SubscriptionPlan?
    @State private var isSavingPlan = false

    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    private let accentOrange = Color(red: 1.0, green: 95.0 / 255.0, blue: 43.0 / 255.0)
    private let pageBackground = Color(red: 0.972, green: 0.972, blue: 0.972)
    private let cardBackground = Color.white
    private let mutedText = Color.black.opacity(0.58)
    private let secondaryText = Color.black.opacity(0.42)
    private let softBorder = Color.black.opacity(0.08)

    private let termsURL = URL(string: "https://lamenu.app/terms")!
    private let privacyURL = URL(string: "https://lamenu.app/privacy-policy")!

    init(
        profileId: UUID,
        currentPlan: SubscriptionPlan,
        currentSmsCredits: Int,
        onPlanPurchased: ((SubscriptionPlan) -> Void)? = nil
    ) {
        self.profileId = profileId
        self.onPlanPurchased = onPlanPurchased

        _activePlan = State(initialValue: currentPlan)
        _activeSmsCredits = State(initialValue: currentSmsCredits)

        print("🟦 PlansView INIT")
        print("🆔 profileId:", profileId.uuidString)
        print("📦 currentPlan:", currentPlan.rawValue)
        print("💬 currentSmsCredits:", currentSmsCredits)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                pageBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        heroSection

                        currentPlanSummary

                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text(String(localized: "Dostępne plany"))
                                    .font(.custom("WixMadeforDisplay-Bold", size: 30))
                                    .foregroundStyle(.black)

                                Spacer()

                                if storeKitManager.isLoading || isSavingPlan {
                                    ProgressView()
                                        .tint(.black)
                                }
                            }

                            ForEach(displayPlans, id: \.self) { plan in
                                planCard(plan)
                            }
                        }

                        restoreButton

                        legalLinksSection

                        Text(String(localized: "Subskrypcje są obsługiwane przez Apple. Możesz nimi zarządzać w ustawieniach swojego konta Apple ID"))
                            .font(.custom("WixMadeforDisplay-Regular", size: 13))
                            .foregroundStyle(secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    closeButton
                }

                ToolbarItem(placement: .principal) {
                    Text(String(localized: "Plany"))
                        .font(.custom("WixMadeforDisplay-SemiBold", size: 17))
                        .foregroundStyle(.black)
                }
            }
            .task {
                print("🟦 PlansView TASK START")
                print("🆔 profileId:", profileId.uuidString)
                print("📦 activePlan before StoreKit:", activePlan.rawValue)
                print("💬 activeSmsCredits before StoreKit:", activeSmsCredits)

                print("🛒 StoreKit loadProducts START")
                await storeKitManager.loadProducts()
                print("🛒 StoreKit loadProducts END")
                print("🛒 StoreKit isLoading:", storeKitManager.isLoading)
                print("🛒 StoreKit errorMessage:", storeKitManager.errorMessage ?? "nil")

                for plan in displayPlans {
                    print("🧾 Product check for plan:", plan.rawValue)
                    print("   productId:", plan.productId ?? "nil")
                    print("   product exists:", storeKitManager.product(for: plan) != nil)
                    print("   isPurchased:", storeKitManager.isPurchased(plan))
                    print("   priceText:", priceText(for: plan))
                }

                print("🔄 Sync purchased subscription START")
                if let syncedPlan = await storeKitManager.syncPurchasedSubscriptionWithSupabase() {
                    print("🔄 Sync result found plan:", syncedPlan.rawValue)

                    let didSave = await applyPlanAndPersist(
                        syncedPlan,
                        source: "PlansView.task syncPurchasedSubscriptionWithSupabase"
                    )

                    print("🔄 Sync apply result:", didSave)
                } else {
                    print("🔄 Sync result: nil")
                    print("🔄 Sync errorMessage:", storeKitManager.errorMessage ?? "nil")
                }

                print("🟦 PlansView TASK END")
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button(String(localized: "OK"), role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private var displayPlans: [SubscriptionPlan] {
        [.free, .plus, .business, .premium]
    }

    private var recommendedPlan: SubscriptionPlan? {
        if activePlan == .business || activePlan == .premium {
            return nil
        }

        return .business
    }

    private var closeButton: some View {
        Button {
            print("❎ PlansView dismissed")
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

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Wybierz plan dla swojego lokalu"))
                .font(.custom("WixMadeforDisplay-Bold", size: 38))
                .foregroundStyle(.black)
                .lineSpacing(-2)

            Text(String(localized: "Porównaj możliwości i wybierz plan najlepiej dopasowany do rozwoju Twojej sprzedaży"))
                .font(.custom("WixMadeforDisplay-Regular", size: 16))
                .foregroundStyle(mutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 6)
    }

    private var currentPlanSummary: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(accentOrange.opacity(0.10))
                    .frame(width: 52, height: 52)

                Image(systemName: activePlan.iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(accentOrange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: String(localized: "Aktywny plan: %@"), localizedPlanTitle(activePlan)))
                    .font(.custom("WixMadeforDisplay-SemiBold", size: 18))
                    .foregroundStyle(.black)

                Text(String(format: String(localized: "Dostępne SMS: %lld"), activeSmsCredits))
                    .font(.custom("WixMadeforDisplay-Regular", size: 14))
                    .foregroundStyle(mutedText)
            }

            Spacer()
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(softBorder, lineWidth: 1)
        )
    }

    private func planCard(_ plan: SubscriptionPlan) -> some View {
        let isCurrent = plan == activePlan
        let isRecommended = recommendedPlan == plan
        let isPurchasing = purchasingPlan == plan
        let isPurchasedInApple = storeKitManager.isPurchased(plan)

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                iconView(for: plan)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(localizedPlanTitle(plan))
                            .font(.custom("WixMadeforDisplay-Bold", size: 28))
                            .foregroundStyle(.black)

                        if isCurrent {
                            badge(
                                text: String(localized: "Aktualny"),
                                textColor: .white,
                                background: accentOrange
                            )
                        } else if isPurchasedInApple {
                            badge(
                                text: String(localized: "Kupiony"),
                                textColor: accentOrange,
                                background: accentOrange.opacity(0.10)
                            )
                        } else if isRecommended {
                            badge(
                                text: String(localized: "Polecany"),
                                textColor: accentOrange,
                                background: accentOrange.opacity(0.10)
                            )
                        }
                    }

                    Text(localizedPlanDescription(plan))
                        .font(.custom("WixMadeforDisplay-Regular", size: 15))
                        .foregroundStyle(mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            VStack(spacing: 12) {
                planRow(title: String(localized: "Cena"), value: priceText(for: plan))
                planRow(title: String(localized: "Limit pozycji"), value: localizedMenuLimitText(plan))
                planRow(title: String(localized: "Pakiet SMS"), value: localizedSmsCreditsText(plan))
            }

            if isCurrent {
                activePlanView
            } else {
                Button {
                    Task {
                        await handlePlanSelection(plan)
                    }
                } label: {
                    HStack(spacing: 10) {
                        if isPurchasing || isSavingPlan {
                            ProgressView()
                                .tint(isRecommended ? .white : .black)
                        } else {
                            Text(buttonTitle(for: plan))
                                .font(.custom("WixMadeforDisplay-SemiBold", size: 17))

                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
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
                .disabled(
                    isPurchasing ||
                    purchasingPlan != nil ||
                    storeKitManager.isPurchasing ||
                    isSavingPlan
                )
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

    private var activePlanView: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accentOrange)

            Text(String(localized: "Ten plan jest obecnie aktywny"))
                .font(.custom("WixMadeforDisplay-Medium", size: 14))
                .foregroundStyle(.black.opacity(0.78))
        }
    }

    private var restoreButton: some View {
        Button {
            Task {
                await restorePurchases()
            }
        } label: {
            Text(String(localized: "Przywróć zakupy"))
                .font(.custom("WixMadeforDisplay-SemiBold", size: 16))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(softBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
        .disabled(isSavingPlan || purchasingPlan != nil || storeKitManager.isPurchasing)
    }

    private var legalLinksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Subskrybując, akceptujesz warunki korzystania z usługi oraz politykę prywatności"))
                .font(.custom("WixMadeforDisplay-Regular", size: 13))
                .foregroundStyle(secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Link(destination: termsURL) {
                    Text(String(localized: "Terms of Use"))
                        .font(.custom("WixMadeforDisplay-SemiBold", size: 14))
                        .foregroundStyle(accentOrange)
                }

                Text("•")
                    .font(.custom("WixMadeforDisplay-Regular", size: 14))
                    .foregroundStyle(secondaryText)

                Link(destination: privacyURL) {
                    Text(String(localized: "Privacy Policy"))
                        .font(.custom("WixMadeforDisplay-SemiBold", size: 14))
                        .foregroundStyle(accentOrange)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(softBorder, lineWidth: 1)
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

    private func badge(
        text: String,
        textColor: Color,
        background: Color
    ) -> some View {
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

            Image(systemName: plan.iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(accentOrange)
        }
    }

    private func buttonTitle(for plan: SubscriptionPlan) -> String {
        if storeKitManager.isPurchased(plan) {
            return String(localized: "Aktywuj plan")
        }

        if plan == recommendedPlan {
            return String(localized: "Przejdź na ten plan")
        }

        return String(localized: "Wybierz plan")
    }

    private func priceText(for plan: SubscriptionPlan) -> String {
        if plan == .free {
            return "$0"
        }

        if let product = storeKitManager.product(for: plan) {
            return String(format: String(localized: "%@ / miesiąc"), product.displayPrice)
        }

        return String(format: String(localized: "%@ / miesiąc"), plan.fallbackPriceText)
    }

    private func smsCredits(for plan: SubscriptionPlan) -> Int {
        switch plan {
        case .free:
            return 20
        case .plus:
            return 200
        case .business:
            return 500
        case .premium:
            return 1500
        }
    }

    private func localizedPlanTitle(_ plan: SubscriptionPlan) -> String {
        switch plan {
        case .free:
            return String(localized: "Free")
        case .plus:
            return String(localized: "Plus")
        case .business:
            return String(localized: "Business")
        case .premium:
            return String(localized: "Premium")
        }
    }

    private func localizedPlanDescription(_ plan: SubscriptionPlan) -> String {
        switch plan {
        case .free:
            return String(localized: "Dobry start dla małego menu")
        case .plus:
            return String(localized: "Więcej pozycji i więcej SMS dla rosnącej sprzedaży")
        case .business:
            return String(localized: "Najlepszy wybór dla aktywnego lokalu")
        case .premium:
            return String(localized: "Maksymalny pakiet dla dużej sprzedaży")
        }
    }

    private func localizedMenuLimitText(_ plan: SubscriptionPlan) -> String {
        switch plan {
        case .free:
            return String(localized: "20 pozycji")
        case .plus, .business, .premium:
            return String(localized: "Bez limitu")
        }
    }

    private func localizedSmsCreditsText(_ plan: SubscriptionPlan) -> String {
        switch plan {
        case .free:
            return String(format: String(localized: "%lld SMS"), 20)
        case .plus:
            return String(format: String(localized: "%lld SMS"), 200)
        case .business:
            return String(format: String(localized: "%lld SMS"), 500)
        case .premium:
            return String(format: String(localized: "%lld SMS"), 1500)
        }
    }
}

// MARK: - Actions

extension PlansView {
    @MainActor
    private func handlePlanSelection(_ plan: SubscriptionPlan) async {
        print("🟧 handlePlanSelection START")
        print("🆔 profileId:", profileId.uuidString)
        print("👆 selected plan:", plan.rawValue)
        print("📦 activePlan before:", activePlan.rawValue)
        print("💬 activeSmsCredits before:", activeSmsCredits)
        print("🛒 storeKitManager.isPurchasing:", storeKitManager.isPurchasing)
        print("💾 isSavingPlan:", isSavingPlan)
        print("🧾 plan.productId:", plan.productId ?? "nil")
        print("🧾 product exists:", storeKitManager.product(for: plan) != nil)
        print("🧾 isPurchased in Apple:", storeKitManager.isPurchased(plan))

        purchasingPlan = plan
        defer {
            purchasingPlan = nil
            print("🟧 handlePlanSelection END")
        }

        if plan == .free {
            print("🆓 Free plan selected")
            let didSave = await applyPlanAndPersist(
                .free,
                source: "handlePlanSelection free"
            )

            print("🆓 Free plan save result:", didSave)

            if didSave {
                showSuccess(
                    title: String(localized: "Plan Free aktywny"),
                    message: String(localized: "Aktywowano plan Free")
                )
            }

            return
        }

        if storeKitManager.isPurchased(plan) {
            print("✅ Plan already purchased in Apple")
            print("🔄 Sync purchased subscription START")

            if let syncedPlan = await storeKitManager.syncPurchasedSubscriptionWithSupabase() {
                print("🔄 syncedPlan:", syncedPlan.rawValue)

                let didSave = await applyPlanAndPersist(
                    syncedPlan,
                    source: "handlePlanSelection already purchased sync"
                )

                print("🔄 synced plan save result:", didSave)

                if didSave {
                    showSuccess(
                        title: String(localized: "Plan aktywny"),
                        message: String(format: String(localized: "Aktywowano plan %@"), localizedPlanTitle(syncedPlan))
                    )
                }
            } else {
                print("❌ Sync returned nil")
                print("❌ StoreKit error:", storeKitManager.errorMessage ?? "nil")

                showError(
                    title: String(localized: "Nie udało się aktywować planu"),
                    message: storeKitManager.errorMessage ?? String(localized: "Spróbuj ponownie albo użyj opcji Przywróć zakupy")
                )
            }

            return
        }

        guard let product = storeKitManager.product(for: plan) else {
            print("❌ Product not found for plan:", plan.rawValue)
            print("❌ productId:", plan.productId ?? "nil")
            print("❌ Check App Store Connect product ID and StoreKit configuration")

            showError(
                title: String(localized: "Produkt niedostępny"),
                message: String(format: String(localized: "Nie znaleziono produktu %@ w StoreKit"), plan.productId ?? "")
            )
            return
        }

        print("🛒 Purchase START")
        print("🛒 Product id:", product.id)
        print("🛒 Product displayName:", product.displayName)
        print("🛒 Product displayPrice:", product.displayPrice)

        if let purchasedPlan = await storeKitManager.purchase(product) {
            print("✅ Purchase returned plan:", purchasedPlan.rawValue)

            let didSave = await applyPlanAndPersist(
                purchasedPlan,
                source: "handlePlanSelection purchase"
            )

            print("✅ purchased plan save result:", didSave)

            if didSave {
                showSuccess(
                    title: String(localized: "Plan został aktywowany"),
                    message: String(format: String(localized: "Aktywowano plan %@"), localizedPlanTitle(purchasedPlan))
                )
            }
        } else {
            print("❌ Purchase returned nil")
            print("❌ StoreKit error:", storeKitManager.errorMessage ?? "nil")

            if let message = storeKitManager.errorMessage {
                showError(
                    title: String(localized: "Błąd zakupu"),
                    message: message
                )
            }
        }
    }

    @MainActor
    private func restorePurchases() async {
        print("🟪 restorePurchases START")
        print("🆔 profileId:", profileId.uuidString)
        print("📦 activePlan before:", activePlan.rawValue)
        print("💬 activeSmsCredits before:", activeSmsCredits)

        purchasingPlan = activePlan
        defer {
            purchasingPlan = nil
            print("🟪 restorePurchases END")
        }

        if let restoredPlan = await storeKitManager.restorePurchases() {
            print("✅ Restored plan:", restoredPlan.rawValue)

            let didSave = await applyPlanAndPersist(
                restoredPlan,
                source: "restorePurchases"
            )

            print("✅ restored plan save result:", didSave)

            if didSave {
                showSuccess(
                    title: String(localized: "Zakupy przywrócone"),
                    message: String(format: String(localized: "Znaleziono aktywny plan %@"), localizedPlanTitle(restoredPlan))
                )
            }
        } else {
            print("❌ restorePurchases returned nil")
            print("❌ StoreKit error:", storeKitManager.errorMessage ?? "nil")

            showError(
                title: String(localized: "Brak aktywnych subskrypcji"),
                message: storeKitManager.errorMessage ?? String(localized: "Nie znaleziono aktywnej subskrypcji na tym koncie Apple")
            )
        }
    }

    @MainActor
    @discardableResult
    private func applyPlanAndPersist(
        _ plan: SubscriptionPlan,
        source: String
    ) async -> Bool {
        print("🟨 applyPlanAndPersist START")
        print("📍 source:", source)
        print("🆔 profileId:", profileId.uuidString)
        print("📦 requested plan:", plan.rawValue)

        let previousPlan = activePlan
        let previousSmsCredits = activeSmsCredits

        print("📦 previousPlan:", previousPlan.rawValue)
        print("💬 previousSmsCredits:", previousSmsCredits)

        let credits = smsCredits(for: plan)

        print("💬 calculated credits:", credits)

        activePlan = plan
        activeSmsCredits = credits

        print("📲 UI updated temporarily")
        print("📦 activePlan temporary:", activePlan.rawValue)
        print("💬 activeSmsCredits temporary:", activeSmsCredits)

        let didSave = await savePlanToSupabase(
            plan,
            smsCredits: credits,
            source: source
        )

        print("💾 savePlanToSupabase result:", didSave)

        if didSave {
            print("✅ Plan persisted successfully")
            print("📣 Calling onPlanPurchased")
            onPlanPurchased?(plan)

            print("📣 Posting NotificationCenter subscriptionPlanDidChange")
            NotificationCenter.default.post(
                name: .subscriptionPlanDidChange,
                object: nil
            )

            print("✅ Final activePlan:", activePlan.rawValue)
            print("✅ Final activeSmsCredits:", activeSmsCredits)
            print("🟨 applyPlanAndPersist END true")

            return true
        } else {
            print("⚠️ Supabase save failed, rollback UI")
            activePlan = previousPlan
            activeSmsCredits = previousSmsCredits

            print("↩️ rollback activePlan:", activePlan.rawValue)
            print("↩️ rollback activeSmsCredits:", activeSmsCredits)
            print("🟨 applyPlanAndPersist END false")

            return false
        }
    }

    @MainActor
    private func savePlanToSupabase(
        _ plan: SubscriptionPlan,
        smsCredits: Int,
        source: String
    ) async -> Bool {
        print("🟥 savePlanToSupabase START")
        print("📍 source:", source)
        print("🆔 profileId:", profileId.uuidString)
        print("📦 plan:", plan.rawValue)
        print("💬 smsCredits:", smsCredits)
        print("💾 isSavingPlan before:", isSavingPlan)

        guard !isSavingPlan else {
            print("⚠️ savePlanToSupabase blocked because isSavingPlan == true")
            return false
        }

        isSavingPlan = true
        defer {
            isSavingPlan = false
            print("🟥 savePlanToSupabase END")
            print("💾 isSavingPlan after:", isSavingPlan)
        }

        do {
            let update = ProfilePlanUpdate(
                subscription_plan: plan.rawValue,
                sms_credits: smsCredits
            )

            print("📤 Supabase UPDATE profiles")
            print("📤 table: profiles")
            print("📤 eq id:", profileId.uuidString)
            print("📤 subscription_plan:", update.subscription_plan)
            print("📤 sms_credits:", update.sms_credits)

            let response = try await SupabaseManager.shared
                .from("profiles")
                .update(update)
                .eq("id", value: profileId.uuidString)
                .execute()

            print("✅ Supabase update success")
            print("✅ Supabase response:", response)
            print("✅ Saved profileId:", profileId.uuidString)
            print("✅ Saved plan:", plan.rawValue)
            print("✅ Saved smsCredits:", smsCredits)

            return true
        } catch {
            print("❌ Supabase update failed")
            print("❌ profileId:", profileId.uuidString)
            print("❌ plan:", plan.rawValue)
            print("❌ smsCredits:", smsCredits)
            print("❌ error type:", String(describing: type(of: error)))
            print("❌ localizedDescription:", error.localizedDescription)
            print("❌ full error:", error)

            showError(
                title: String(localized: "Plan nie został zapisany"),
                message: String(localized: "Nie udało się zapisać planu w bazie. Sprawdź logi w Xcode")
            )

            return false
        }
    }

    @MainActor
    private func showError(title: String, message: String) {
        print("🚨 showError")
        print("🚨 title:", title)
        print("🚨 message:", message)

        alertTitle = title
        alertMessage = message
        showAlert = true
    }

    @MainActor
    private func showSuccess(title: String, message: String) {
        print("✅ showSuccess")
        print("✅ title:", title)
        print("✅ message:", message)

        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

// MARK: - Supabase DTO

private struct ProfilePlanUpdate: Encodable {
    let subscription_plan: String
    let sms_credits: Int
}

// MARK: - Notifications

extension Notification.Name {
    static let subscriptionPlanDidChange = Notification.Name("subscriptionPlanDidChange")
}

#Preview {
    NavigationStack {
        PlansView(
            profileId: UUID(),
            currentPlan: .free,
            currentSmsCredits: 20
        ) { plan in
            print("Purchased plan:", plan.rawValue)
        }
    }
}
