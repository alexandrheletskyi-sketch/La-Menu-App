import Foundation

struct MenuItem: Codable, Identifiable, Hashable {
    let id: UUID
    let categoryID: UUID
    let name: String
    let description: String?
    let price: Double
    let oldPrice: Double?
    let weight: String?
    let imageURL: String?
    let allergens: String?
    let tags: String?
    let isRecommended: Bool
    let isSpicy: Bool
    let isVegetarian: Bool
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
