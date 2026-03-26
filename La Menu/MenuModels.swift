import Foundation

struct MenuRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let profileID: UUID
    var title: String
    var slug: String?
    var description: String?
    var currency: String
    var isActive: Bool
    var isPublic: Bool
    var sortOrder: Int
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case profileID = "profile_id"
        case title
        case slug
        case description
        case currency
        case isActive = "is_active"
        case isPublic = "is_public"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct MenuCategory: Identifiable, Codable, Hashable {
    let id: UUID
    let menuID: UUID
    var name: String
    var description: String?
    var isActive: Bool
    var sortOrder: Int
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case menuID = "menu_id"
        case name
        case description
        case isActive = "is_active"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct MenuItem: Identifiable, Codable, Hashable {
    let id: UUID
    let categoryID: UUID
    var name: String
    var description: String?
    var price: Double
    var oldPrice: Double?
    var weight: String?
    var imageURL: String?
    var allergens: String?
    var tags: String?
    var isRecommended: Bool
    var isSpicy: Bool
    var isVegetarian: Bool
    var isAvailable: Bool
    var sortOrder: Int
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case categoryID = "category_id"
        case name
        case description
        case price
        case oldPrice = "old_price"
        case weight
        case imageURL = "image_url"
        case allergens
        case tags
        case isRecommended = "is_recommended"
        case isSpicy = "is_spicy"
        case isVegetarian = "is_vegetarian"
        case isAvailable = "is_available"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
