import Foundation

struct UserProfile: Codable, Identifiable, Equatable {
    let id: UUID
    let email: String?
    let displayName: String
    let avatarURL: URL?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct NewUserProfile: Encodable {
    let id: UUID
    let email: String?
    let displayName: String
    let avatarURL: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case avatarURL = "avatar_url"
    }
}
