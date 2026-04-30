import Foundation

struct MenuItem: Codable, Identifiable, Hashable {
    let id: UUID
    let categoryID: UUID
    let name: String
    let description: String?
    let price: Double
    let weight: String?
    let allergens: [String]?
    let imageURL: String?
    let isAvailable: Bool
    let sortOrder: Int
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case categoryID = "category_id"
        case name
        case description
        case price
        case weight
        case allergens
        case imageURL = "image_url"
        case isAvailable = "is_available"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct MenuItemDraft {
    var name: String
    var description: String
    var price: Double
    var weight: String
    var allergensText: String
    var imageData: Data?
}

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
