import SwiftUI
import Supabase
import PostgREST

struct ContentView: View {
    @State private var menus: [MenuRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("La Menu")
                        .font(.largeTitle.bold())

                    Text("Manage your restaurant menus and public links")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if isLoading {
                        ProgressView("Loading...")
                    }

                    if let errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if !isLoading {
                        VStack(spacing: 12) {
                            dashboardCard(
                                title: "Menus",
                                value: "\(menus.count)",
                                icon: "menucard.fill"
                            )

                            dashboardCard(
                                title: "Status",
                                value: menus.isEmpty ? "Empty" : "Ready",
                                icon: "checkmark.circle.fill"
                            )
                        }

                        if !menus.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Your menus")
                                    .font(.headline)

                                ForEach(menus) { menu in
                                    NavigationLink {
                                        MenuDetailView(menu: menu)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(menu.title)
                                                .font(.headline)
                                                .foregroundStyle(.primary)

                                            if let description = menu.description, !description.isEmpty {
                                                Text(description)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Text(menu.currency)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(18)
                                        .background(Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 22))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Home")
            .task {
                await loadMenus()
            }
        }
    }

    private func dashboardCard(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.title3.bold())
            }

            Spacer()
        }
        .padding(18)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    @MainActor
    private func loadMenus() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: [MenuRecord] = try await SupabaseManager.shared
                .from("menus")
                .select()
                .order("sort_order", ascending: true)
                .execute()
                .value

            menus = response
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
}
