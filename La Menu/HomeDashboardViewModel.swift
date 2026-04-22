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
                self.isWithinWorkingHours = false
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

            // Tymczasowo:
            // jeśli ręczne przyjmowanie jest włączone, pokazujemy lokal jako aktywny
            // później możesz tu wstawić realne wyliczenie na podstawie godzin pracy
            self.isWithinWorkingHours = true

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
