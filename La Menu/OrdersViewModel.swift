import Foundation
import Observation
import Supabase
import PostgREST

@MainActor
@Observable
final class OrdersViewModel {
    var orders: [Order] = []
    var orderItemsByOrderId: [UUID: [OrderItem]] = [:]

    var isLoading = false
    var errorMessage: String?

    func load(profileID: UUID) async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            print("========== ORDERS DEBUG START ==========")
            print("DEBUG current profileID:", profileID.uuidString)

            let loadedOrders: [Order] = try await SupabaseManager.shared
                .from("orders")
                .select()
                .eq("profile_id", value: profileID.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            print("DEBUG filtered orders count:", loadedOrders.count)

            if loadedOrders.isEmpty {
                print("DEBUG no orders found for this profile_id")
                print("DEBUG trying to load all orders without filter")

                let allOrders: [Order] = try await SupabaseManager.shared
                    .from("orders")
                    .select()
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                print("DEBUG all orders count:", allOrders.count)

                for order in allOrders {
                    print("""
                    DEBUG all order:
                    - id: \(order.id.uuidString)
                    - profile_id: \(order.profileId.uuidString)
                    - customer_name: \(order.customerName ?? "nil")
                    - status: \(order.status)
                    - created_at: \(order.createdAt)
                    """)
                }
            } else {
                for order in loadedOrders {
                    print("""
                    DEBUG loaded order:
                    - id: \(order.id.uuidString)
                    - profile_id: \(order.profileId.uuidString)
                    - customer_name: \(order.customerName ?? "nil")
                    - status: \(order.status)
                    - created_at: \(order.createdAt)
                    """)
                }
            }

            self.orders = loadedOrders

            let orderIds = loadedOrders.map { $0.id.uuidString }
            print("DEBUG loaded orderIds:", orderIds)

            if orderIds.isEmpty {
                self.orderItemsByOrderId = [:]
                print("DEBUG no order items to load")
                print("========== ORDERS DEBUG END ==========")
                return
            }

            let loadedItems: [OrderItem] = try await SupabaseManager.shared
                .from("order_items")
                .select()
                .in("order_id", values: orderIds)
                .order("created_at", ascending: true)
                .execute()
                .value

            print("DEBUG loaded order_items count:", loadedItems.count)

            for item in loadedItems {
                print("""
                DEBUG loaded item:
                - id: \(item.id.uuidString)
                - order_id: \(item.orderId.uuidString)
                - name: \(item.name)
                - quantity: \(item.quantity)
                - line_total: \(item.lineTotal)
                """)
            }

            self.orderItemsByOrderId = Dictionary(grouping: loadedItems, by: { $0.orderId })

            print("DEBUG grouped order items keys:", self.orderItemsByOrderId.keys.map { $0.uuidString })
            print("========== ORDERS DEBUG END ==========")

        } catch {
            print("========== ORDERS DEBUG ERROR ==========")
            print("DEBUG error:", error)
            print("DEBUG localizedDescription:", error.localizedDescription)
            print("=======================================")

            errorMessage = error.localizedDescription
        }
    }

    func items(for order: Order) -> [OrderItem] {
        orderItemsByOrderId[order.id] ?? []
    }

    func updateStatus(orderID: UUID, status: String) async {
        do {
            print("DEBUG updateStatus orderID:", orderID.uuidString, "new status:", status)

            try await SupabaseManager.shared
                .from("orders")
                .update([
                    "status": status,
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: orderID.uuidString)
                .execute()

            if let index = orders.firstIndex(where: { $0.id == orderID }) {
                let current = orders[index]
                orders[index] = Order(
                    id: current.id,
                    profileId: current.profileId,
                    customerName: current.customerName,
                    customerPhone: current.customerPhone,
                    fulfillmentType: current.fulfillmentType,
                    pickupTime: current.pickupTime,
                    totalAmount: current.totalAmount,
                    status: status,
                    createdAt: current.createdAt,
                    updatedAt: ISO8601DateFormatter().string(from: Date())
                )
            }

            print("DEBUG status updated successfully")

        } catch {
            print("DEBUG updateStatus error:", error)
            errorMessage = error.localizedDescription
        }
    }

    func itemsText(for order: Order) -> String {
        let items = items(for: order)

        return items.map {
            "\($0.name) x\($0.quantity) - \(Int($0.lineTotal)) zł"
        }
        .joined(separator: "\n")
    }
}
