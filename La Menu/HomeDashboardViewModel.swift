import Foundation
import Observation
import Supabase
import PostgREST

@MainActor
@Observable
final class HomeDashboardViewModel {
    var profile: Profile?
    var mainMenu: MenuRecord?
    var ordersTodayCount: Int = 0
    var revenueToday: Double = 0
    var recentOrders: [Order] = []
    var orderItemsByOrderId: [UUID: [OrderItem]] = [:]

    var isLoading = false
    var errorMessage: String?

    func load(for userId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let profiles: [Profile] = try await SupabaseManager.shared
                .from("profiles")
                .select()
                .eq("owner_user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            guard let profile = profiles.first else {
                self.profile = nil
                self.mainMenu = nil
                self.ordersTodayCount = 0
                self.revenueToday = 0
                self.recentOrders = []
                self.orderItemsByOrderId = [:]
                return
            }

            self.profile = profile

            let menus: [MenuRecord] = try await SupabaseManager.shared
                .from("menus")
                .select()
                .eq("profile_id", value: profile.id.uuidString)
                .order("sort_order", ascending: true)
                .limit(1)
                .execute()
                .value

            self.mainMenu = menus.first

            let allOrders: [Order] = try await SupabaseManager.shared
                .from("orders")
                .select()
                .eq("profile_id", value: profile.id.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            let todayPrefix = Self.todayDatePrefix()
            let todayOrders = allOrders.filter { $0.createdAt.hasPrefix(todayPrefix) }

            self.ordersTodayCount = todayOrders.count
            self.revenueToday = todayOrders.reduce(0) { $0 + $1.totalAmount }
            self.recentOrders = Array(allOrders.prefix(5))

            let orderIds = recentOrders.map { $0.id.uuidString }

            if !orderIds.isEmpty {
                let allItems: [OrderItem] = try await SupabaseManager.shared
                    .from("order_items")
                    .select()
                    .in("order_id", values: orderIds)
                    .execute()
                    .value

                self.orderItemsByOrderId = Dictionary(grouping: allItems, by: { $0.orderId })
            } else {
                self.orderItemsByOrderId = [:]
            }

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleAcceptingOrders() async {
        guard let profile else { return }

        let newValue = !profile.isAcceptingOrders

        do {
            try await SupabaseManager.shared
                .from("profiles")
                .update(["is_accepting_orders": newValue])
                .eq("id", value: profile.id.uuidString)
                .execute()

            self.profile = Profile(
                id: profile.id,
                ownerUserId: profile.ownerUserId,
                businessName: profile.businessName,
                username: profile.username,
                description: profile.description,
                phone: profile.phone,
                email: profile.email,
                address: profile.address,
                logoURL: profile.logoURL,
                coverURL: profile.coverURL,
                isActive: profile.isActive,
                isAcceptingOrders: newValue,
                onboardingCompleted: profile.onboardingCompleted,
                pickupEnabled: profile.pickupEnabled,
                deliveryEnabled: profile.deliveryEnabled,
                accentColor: profile.accentColor,
                slotIntervalMinutes: profile.slotIntervalMinutes,
                deliveryPricePerKm: profile.deliveryPricePerKm,
                smsConfirmationEnabled: profile.smsConfirmationEnabled,
                createdAt: profile.createdAt,
                updatedAt: profile.updatedAt
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func itemsText(for order: Order) -> String {
        let items = orderItemsByOrderId[order.id] ?? []

        return items.map {
            "\($0.name) x\($0.quantity) - \(Int($0.lineTotal)) zł"
        }
        .joined(separator: "\n")
    }

    private static func todayDatePrefix() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
