import SwiftUI

struct OrdersView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No orders yet",
                systemImage: "cart",
                description: Text("Recent orders will appear here")
            )
            .navigationTitle("Orders")
        }
    }
}

#Preview {
    OrdersView()
}
