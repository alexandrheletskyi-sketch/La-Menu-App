import SwiftUI
import Supabase
import PostgREST

struct MenuDetailView: View {
    let menu: MenuRecord

    @State private var categories: [MenuCategory] = []
    @State private var items: [MenuItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(menu.title)
                    .font(.largeTitle.bold())

                if let description = menu.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if isLoading {
                    ProgressView("Ładowanie...")
                        .padding(.top, 12)
                }

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                ForEach(categories) { category in
                    let categoryItems = items
                        .filter { $0.categoryID == category.id }
                        .sorted { $0.sortOrder < $1.sortOrder }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(category.name)
                            .font(.title2.bold())

                        if let description = category.description, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if categoryItems.isEmpty {
                            Text("Brak pozycji")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(categoryItems) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.name)
                                                .font(.headline)

                                            if let description = item.description, !description.isEmpty {
                                                Text(description)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                            }

                                            if let weight = item.weight, !weight.isEmpty {
                                                Text(weight)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            if let allergens = item.allergens, !allergens.isEmpty {
                                                Text("Alergeny: \(allergens)")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text("\(item.price, specifier: "%.0f") zł")
                                                .font(.headline)

                                            if !item.isAvailable {
                                                Text("Niedostępne")
                                                    .font(.caption2)
                                                    .foregroundStyle(.red)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Menu")
        .task {
            await loadMenu()
        }
    }

    private func loadMenu() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let loadedCategories: [MenuCategory] = try await SupabaseManager.shared
                .from("menu_categories")
                .select()
                .eq("menu_id", value: menu.id.uuidString)
                .order("sort_order", ascending: true)
                .execute()
                .value

            let categoryIDs = loadedCategories.map { $0.id.uuidString }

            let loadedItems: [MenuItem]
            if categoryIDs.isEmpty {
                loadedItems = []
            } else {
                loadedItems = try await SupabaseManager.shared
                    .from("menu_items")
                    .select()
                    .in("category_id", values: categoryIDs)
                    .order("sort_order", ascending: true)
                    .execute()
                    .value
            }

            categories = loadedCategories
            items = loadedItems
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading menu:", error)
        }
    }
}
