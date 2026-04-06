import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeDashboardView()
                .tabItem {
                    Label("Główny", systemImage: "house.fill")
                }

            OrdersView()
                .tabItem {
                    Label("Zamówienie", systemImage: "square.grid.2x2.fill")
                }

            MenusView()
                .tabItem {
                    Label("Menu", systemImage: "list.bullet.rectangle.fill")
                }

            ProfileView()
                .tabItem {
                    Label("Profil", systemImage: "person.fill")
                }
        }
        .font(.custom("WixMadeforDisplay-Regular", size: 14))
        .tint(.black)
    }
}
