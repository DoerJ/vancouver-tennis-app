import Foundation

struct UserProfile: Codable, Identifiable, Equatable {
    let id: UUID
    let email: String?
    let displayName: String
    let avatarURL: URL?
    let skillLevel: SkillLevel?
    let hostedEvents: [UUID]
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case skillLevel = "skill_level"
        case hostedEvents = "hosted_events"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct NewUserProfile: Encodable {
    let id: UUID
    let email: String?
    let displayName: String
    let avatarURL: URL?
    let skillLevel: SkillLevel?
    let hostedEvents: [UUID]

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case skillLevel = "skill_level"
        case hostedEvents = "hosted_events"
    }
}

struct UpdateUserProfile: Encodable {
    let displayName: String?
    let skillLevel: SkillLevel?
    let hostedEvents: [UUID]?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case skillLevel = "skill_level"
        case hostedEvents = "hosted_events"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(skillLevel, forKey: .skillLevel)
        try container.encodeIfPresent(hostedEvents, forKey: .hostedEvents)
    }
}
