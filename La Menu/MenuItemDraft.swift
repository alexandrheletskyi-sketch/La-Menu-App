import Foundation

struct MenuItemDraft {
    var name: String
    var description: String
    var price: Double
    var oldPrice: Double?
    var weight: String
    var allergens: String
    var tags: String
    var isRecommended: Bool
    var isSpicy: Bool
    var isVegetarian: Bool
    var imageData: Data?
}
