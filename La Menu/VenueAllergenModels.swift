import Foundation

struct VenueAllergenRecord: Codable, Identifiable, Hashable {
    let id: UUID
    let profileID: UUID
    let code: String
    let title: String
    let description: String?
    let sortOrder: Int
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case profileID = "profile_id"
        case code
        case title
        case description
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct InsertVenueAllergen: Encodable {
    let profile_id: UUID
    let code: String
    let title: String
    let description: String?
    let sort_order: Int
}
