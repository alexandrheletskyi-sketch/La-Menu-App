import Foundation
import Observation
import Supabase
import PostgREST

@MainActor
@Observable
final class MenusViewModel {
    var menu: MenuRecord?
    var categories: [MenuCategory] = []
    var items: [MenuItem] = []

    var isLoading = false
    var errorMessage: String?

    func load(profileID: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let menu = try await fetchOrCreateMenu(profileID: profileID)
            self.menu = menu
            try await reloadCurrentMenu()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchOrCreateMenu(profileID: UUID) async throws -> MenuRecord {
        let existing: [MenuRecord] = try await SupabaseManager.shared
            .from("menus")
            .select()
            .eq("profile_id", value: profileID.uuidString)
            .order("sort_order", ascending: true)
            .limit(1)
            .execute()
            .value

        if let first = existing.first {
            return first
        }

        struct InsertMenu: Encodable {
            let profile_id: UUID
            let title: String
            let slug: String?
            let description: String?
            let currency: String
            let is_active: Bool
            let is_public: Bool
            let sort_order: Int
        }

        let payload = InsertMenu(
            profile_id: profileID,
            title: "Moje menu",
            slug: nil,
            description: nil,
            currency: "PLN",
            is_active: true,
            is_public: true,
            sort_order: 0
        )

        let created: [MenuRecord] = try await SupabaseManager.shared
            .from("menus")
            .insert(payload)
            .select()
            .execute()
            .value

        guard let createdMenu = created.first else {
            throw NSError(
                domain: "MenusViewModel",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Nie udało się utworzyć menu"
                ]
            )
        }

        return createdMenu
    }

    func addCategory(name: String, description: String = "") async {
        guard let menu else { return }

        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanName.isEmpty else { return }

        errorMessage = nil

        do {
            struct InsertCategory: Encodable {
                let menu_id: UUID
                let name: String
                let description: String?
                let is_active: Bool
                let sort_order: Int
            }

            let payload = InsertCategory(
                menu_id: menu.id,
                name: cleanName,
                description: cleanDescription.isEmpty ? nil : cleanDescription,
                is_active: true,
                sort_order: categories.count
            )

            try await SupabaseManager.shared
                .from("menu_categories")
                .insert(payload)
                .execute()

            try await reloadCurrentMenu()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addItem(
        categoryID: UUID,
        name: String,
        description: String,
        price: Double,
        oldPrice: Double? = nil,
        weight: String = "",
        allergens: String = "",
        tags: String = "",
        isRecommended: Bool = false,
        isSpicy: Bool = false,
        isVegetarian: Bool = false,
        imageData: Data? = nil
    ) async {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanWeight = weight.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAllergens = allergens.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTags = tags.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanName.isEmpty else { return }

        errorMessage = nil

        do {
            let uploadedImageURL: String?
            if let imageData, !imageData.isEmpty {
                uploadedImageURL = try await uploadItemImage(data: imageData)
            } else {
                uploadedImageURL = nil
            }

            struct InsertItem: Encodable {
                let category_id: UUID
                let name: String
                let description: String?
                let price: Double
                let old_price: Double?
                let weight: String?
                let image_url: String?
                let allergens: String?
                let tags: String?
                let is_recommended: Bool
                let is_spicy: Bool
                let is_vegetarian: Bool
                let is_available: Bool
                let sort_order: Int
            }

            let sortOrder = items.filter { $0.categoryID == categoryID }.count

            let payload = InsertItem(
                category_id: categoryID,
                name: cleanName,
                description: cleanDescription.isEmpty ? nil : cleanDescription,
                price: price,
                old_price: oldPrice,
                weight: cleanWeight.isEmpty ? nil : cleanWeight,
                image_url: uploadedImageURL,
                allergens: cleanAllergens.isEmpty ? nil : cleanAllergens,
                tags: cleanTags.isEmpty ? nil : cleanTags,
                is_recommended: isRecommended,
                is_spicy: isSpicy,
                is_vegetarian: isVegetarian,
                is_available: true,
                sort_order: sortOrder
            )

            try await SupabaseManager.shared
                .from("menu_items")
                .insert(payload)
                .execute()

            try await reloadCurrentMenu()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteCategory(_ category: MenuCategory) async {
        errorMessage = nil

        do {
            try await SupabaseManager.shared
                .from("menu_categories")
                .delete()
                .eq("id", value: category.id.uuidString)
                .execute()

            try await reloadCurrentMenu()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteItem(_ item: MenuItem) async {
        errorMessage = nil

        do {
            try await SupabaseManager.shared
                .from("menu_items")
                .delete()
                .eq("id", value: item.id.uuidString)
                .execute()

            try await reloadCurrentMenu()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func items(for categoryID: UUID) -> [MenuItem] {
        items
            .filter { $0.categoryID == categoryID }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private func reloadCurrentMenu() async throws {
        guard let menu else { return }

        async let categoriesTask: [MenuCategory] = SupabaseManager.shared
            .from("menu_categories")
            .select()
            .eq("menu_id", value: menu.id.uuidString)
            .order("sort_order", ascending: true)
            .execute()
            .value

        async let itemsTask: [MenuItem] = SupabaseManager.shared
            .from("menu_items")
            .select()
            .order("sort_order", ascending: true)
            .execute()
            .value

        let loadedCategories = try await categoriesTask
        let allItems = try await itemsTask
        let categoryIDs = Set(loadedCategories.map(\.id))

        self.categories = loadedCategories
        self.items = allItems.filter { categoryIDs.contains($0.categoryID) }
    }

    private func uploadItemImage(data: Data) async throws -> String {
        let fileName = "\(UUID().uuidString).jpg"

        try await SupabaseManager.shared.storage
            .from("menu-items")
            .upload(
                path: fileName,
                file: data,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: false
                )
            )

        let publicURL = try SupabaseManager.shared.storage
            .from("menu-items")
            .getPublicURL(path: fileName)

        return publicURL.absoluteString
    }
}
