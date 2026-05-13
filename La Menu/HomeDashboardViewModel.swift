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

    // Tymczasowo zostawiamy prostą wartość
    // Później możesz tu podpiąć realną logikę z business_hours / slot settings
    var isWithinWorkingHours: Bool = true

    var isEffectivelyAcceptingOrders: Bool {
        guard let profile else { return false }

        if !profile.isAcceptingOrders {
            return false
        }

        if isWithinWorkingHours {
            return true
        }

        return profile.continueAfterHours
    }

    var effectiveOrdersStatusTitle: String {
        guard let profile else { return "Zamówienia wstrzymane" }

        if !profile.isAcceptingOrders {
            return "Zamówienia wstrzymane"
        }

        if isWithinWorkingHours {
            return "Otwarte na zamówienia"
        }

        if profile.continueAfterHours {
            return "Przedłużone przyjmowanie zamówień"
        }

        return "Poza godzinami pracy"
    }

    func load(for userId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            print("========== HOME DASHBOARD DEBUG START ==========")
            print("DEBUG userId:", userId.uuidString)

            let profiles: [Profile] = try await SupabaseManager.shared
                .from("profiles")
                .select()
                .eq("owner_user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            guard let profile = profiles.first else {
                print("DEBUG no profile found")

                self.profile = nil
                self.mainMenu = nil
                self.ordersTodayCount = 0
                self.revenueToday = 0
                self.recentOrders = []
                self.orderItemsByOrderId = [:]
                self.isWithinWorkingHours = false

                print("========== HOME DASHBOARD DEBUG END ==========")
                return
            }

            print("DEBUG profile id:", profile.id.uuidString)
            print("DEBUG profile business:", profile.businessName)

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

            print("DEBUG dashboard orders count:", allOrders.count)

            let todayPrefix = Self.todayDatePrefix()
            let todayOrders = allOrders.filter { $0.createdAt.hasPrefix(todayPrefix) }

            self.ordersTodayCount = todayOrders.count
            self.revenueToday = todayOrders.reduce(0) { $0 + $1.totalAmount }

            self.recentOrders = allOrders

            let orderIds = allOrders.map { $0.id.uuidString }
            print("DEBUG dashboard orderIds:", orderIds)

            if !orderIds.isEmpty {
                let allItems: [OrderItem] = try await SupabaseManager.shared
                    .from("order_items")
                    .select("id, order_id, menu_item_id, name, quantity, unit_price, line_total, created_at")
                    .in("order_id", values: orderIds)
                    .order("created_at", ascending: true)
                    .execute()
                    .value

                print("DEBUG dashboard order_items count:", allItems.count)

                for item in allItems {
                    print("""
                    DEBUG dashboard item:
                    - id: \(item.id.uuidString)
                    - order_id: \(item.orderId.uuidString)
                    - name: \(item.name)
                    - quantity: \(item.quantity)
                    - unit_price: \(item.unitPrice)
                    - line_total: \(item.lineTotal)
                    """)
                }

                self.orderItemsByOrderId = Dictionary(grouping: allItems, by: { $0.orderId })

                print("DEBUG dashboard grouped item keys:", self.orderItemsByOrderId.keys.map { $0.uuidString })
            } else {
                self.orderItemsByOrderId = [:]
                print("DEBUG dashboard no order items to load")
            }

            self.isWithinWorkingHours = true

            print("========== HOME DASHBOARD DEBUG END ==========")

        } catch {
            print("========== HOME DASHBOARD DEBUG ERROR ==========")
            print("DEBUG error:", error)
            print("DEBUG localizedDescription:", error.localizedDescription)
            print("==============================================")

            errorMessage = error.localizedDescription
        }
    }

    func updateStatus(orderID: UUID, status: String) async {
        struct OrderStatusUpdatePayload: Encodable {
            let status: String
        }

        do {
            try await SupabaseManager.shared
                .from("orders")
                .update(OrderStatusUpdatePayload(status: status))
                .eq("id", value: orderID.uuidString)
                .execute()

            if let index = recentOrders.firstIndex(where: { $0.id == orderID }) {
                recentOrders[index].status = status
            }

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleAcceptingOrders() async {
        guard let profile else { return }

        let newValue = !profile.isAcceptingOrders

        struct AcceptingOrdersUpdatePayload: Encodable {
            let is_accepting_orders: Bool
        }

        do {
            try await SupabaseManager.shared
                .from("profiles")
                .update(AcceptingOrdersUpdatePayload(is_accepting_orders: newValue))
                .eq("id", value: profile.id.uuidString)
                .execute()

            self.profile?.isAcceptingOrders = newValue
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleContinueAfterHours() async {
        guard let profile else { return }

        let newValue = !profile.continueAfterHours

        struct ContinueAfterHoursUpdatePayload: Encodable {
            let continue_after_hours: Bool
        }

        do {
            try await SupabaseManager.shared
                .from("profiles")
                .update(ContinueAfterHoursUpdatePayload(continue_after_hours: newValue))
                .eq("id", value: profile.id.uuidString)
                .execute()

            self.profile?.continueAfterHours = newValue
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func itemsText(for order: Order) -> String {
        let items = orderItemsByOrderId[order.id] ?? []

        return items.map { item in
            "\(item.quantity)x \(item.name) — \(Int(item.lineTotal)) zł"
        }
        .joined(separator: "\n")
    }

    private static func todayDatePrefix() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
