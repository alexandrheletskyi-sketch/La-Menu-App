import Foundation
import StoreKit
import Observation

@MainActor
@Observable
final class StoreKitManager {
    var products: [Product] = []
    var purchasedProductIDs: Set<String> = []
    var isLoading = false
    var isPurchasing = false
    var errorMessage: String?

    private let productIDs: Set<String> = [
        "lamenu.plus.monthly",
        "lamenu.business.monthly",
        "lamenu.premium.monthly"
    ]

    func loadProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            let loadedProducts = try await Product.products(for: productIDs)

            products = loadedProducts.sorted { first, second in
                planSortIndex(for: first.id) < planSortIndex(for: second.id)
            }

            await updatePurchasedProducts()
        } catch {
            errorMessage = "Nie udało się pobrać planów"
            print("❌ StoreKit loadProducts error:", error.localizedDescription)
        }

        isLoading = false
    }

    func purchase(_ product: Product) async -> SubscriptionPlan? {
        errorMessage = nil
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)

                guard let plan = SubscriptionPlan.fromProductId(transaction.productID) else {
                    await transaction.finish()
                    errorMessage = "Nieznany produkt subskrypcji"
                    print("⚠️ Unknown product id:", transaction.productID)
                    return nil
                }

                do {
                    try await activatePlanInSupabase(productId: transaction.productID)

                    await updatePurchasedProducts()

                    await transaction.finish()

                    print("✅ Purchase completed and synced:", transaction.productID)

                    return plan
                } catch {
                    errorMessage = "Zakup zakończony, ale nie udało się aktywować planu. Spróbuj przywrócić zakupy."
                    print("❌ Supabase subscription sync error:", error.localizedDescription)

                    return nil
                }

            case .userCancelled:
                return nil

            case .pending:
                errorMessage = "Zakup oczekuje na potwierdzenie"
                return nil

            @unknown default:
                errorMessage = "Nieznany status zakupu"
                return nil
            }
        } catch {
            errorMessage = "Nie udało się wykonać zakupu"
            print("❌ StoreKit purchase error:", error.localizedDescription)
            return nil
        }
    }

    func updatePurchasedProducts() async {
        var purchasedIDs = Set<String>()

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                guard transaction.revocationDate == nil else {
                    continue
                }

                guard productIDs.contains(transaction.productID) else {
                    continue
                }

                purchasedIDs.insert(transaction.productID)
            } catch {
                print("❌ Transaction verification failed:", error.localizedDescription)
            }
        }

        purchasedProductIDs = purchasedIDs
    }

    func syncPurchasedSubscriptionWithSupabase() async -> SubscriptionPlan? {
        errorMessage = nil

        var activeProductIDs = Set<String>()

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                guard transaction.revocationDate == nil else {
                    continue
                }

                guard productIDs.contains(transaction.productID) else {
                    continue
                }

                activeProductIDs.insert(transaction.productID)
            } catch {
                print("❌ Entitlement verification failed:", error.localizedDescription)
            }
        }

        purchasedProductIDs = activeProductIDs

        guard let bestProductId = bestProductId(from: activeProductIDs) else {
            print("ℹ️ No active paid subscription found")
            return nil
        }

        do {
            try await activatePlanInSupabase(productId: bestProductId)

            let plan = SubscriptionPlan.fromProductId(bestProductId)

            print("✅ Purchased subscription synced with Supabase:", bestProductId)

            return plan
        } catch {
            errorMessage = "Nie udało się zsynchronizować planu"
            print("❌ Supabase sync purchased subscription error:", error.localizedDescription)

            return nil
        }
    }

    func restorePurchases() async -> SubscriptionPlan? {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()

            return await syncPurchasedSubscriptionWithSupabase()
        } catch {
            errorMessage = "Nie udało się przywrócić zakupów"
            print("❌ Restore purchases error:", error.localizedDescription)
            return nil
        }
    }

    func product(for plan: SubscriptionPlan) -> Product? {
        guard let productId = plan.productId else {
            return nil
        }

        return products.first { $0.id == productId }
    }

    func isPurchased(_ plan: SubscriptionPlan) -> Bool {
        guard let productId = plan.productId else {
            return false
        }

        return purchasedProductIDs.contains(productId)
    }

    private func activatePlanInSupabase(productId: String) async throws {
        guard let planCode = planCode(for: productId) else {
            print("⚠️ Unknown StoreKit product id:", productId)
            return
        }

        try await SupabaseManager.activateSubscriptionForCurrentProfile(
            planCode: planCode,
            provider: "apple",
            providerProductId: productId
        )

        print("✅ Supabase plan activated:", planCode)
    }

    private func planCode(for productId: String) -> String? {
        switch productId {
        case "lamenu.plus.monthly":
            return "plus"
        case "lamenu.business.monthly":
            return "business"
        case "lamenu.premium.monthly":
            return "premium"
        default:
            return nil
        }
    }

    private func bestProductId(from productIds: Set<String>) -> String? {
        productIds.sorted {
            planSortIndex(for: $0) > planSortIndex(for: $1)
        }.first
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.failedVerification

        case .verified(let safe):
            return safe
        }
    }

    private func planSortIndex(for productId: String) -> Int {
        switch productId {
        case "lamenu.plus.monthly":
            return 1
        case "lamenu.business.monthly":
            return 2
        case "lamenu.premium.monthly":
            return 3
        default:
            return 0
        }
    }
}

enum StoreKitError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Nie udało się zweryfikować transakcji"
        }
    }
}
