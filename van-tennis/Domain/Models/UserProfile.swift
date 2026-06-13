import Foundation

struct UserProfile: Codable, Identifiable, Equatable {
    let id: UUID
    let email: String?
    let displayName: String
    let avatarURL: URL?
    let skillLevel: SkillLevel?
    let gender: Gender?
    let hostedEvents: [UUID]
    let participatedEvents: [UUID]
    let notifications: [UUID]
    let socialTags: [String]
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case skillLevel = "skill_level"
        case gender
        case hostedEvents = "hosted_events"
        case participatedEvents = "participated_events"
        case notifications
        case socialTags = "social_tags"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension UserProfile {
    func updatingEvents(hostedEvents: [UUID], participatedEvents: [UUID]) -> UserProfile {
        UserProfile(
            id: id,
            email: email,
            displayName: displayName,
            avatarURL: avatarURL,
            skillLevel: skillLevel,
            gender: gender,
            hostedEvents: hostedEvents,
            participatedEvents: participatedEvents,
            notifications: notifications,
            socialTags: socialTags,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func updatingNotifications(_ notifications: [UUID]) -> UserProfile {
        UserProfile(
            id: id,
            email: email,
            displayName: displayName,
            avatarURL: avatarURL,
            skillLevel: skillLevel,
            gender: gender,
            hostedEvents: hostedEvents,
            participatedEvents: participatedEvents,
            notifications: notifications,
            socialTags: socialTags,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct NewUserProfile: Encodable {
    let id: UUID
    let email: String?
    let displayName: String
    let avatarURL: URL?
    let skillLevel: SkillLevel?
    let gender: Gender?
    let hostedEvents: [UUID]
    let participatedEvents: [UUID]
    let notifications: [UUID]
    let socialTags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case skillLevel = "skill_level"
        case gender
        case hostedEvents = "hosted_events"
        case participatedEvents = "participated_events"
        case notifications
        case socialTags = "social_tags"
    }
}

struct UpdateUserProfile: Encodable {
    let displayName: String?
    let skillLevel: SkillLevel?
    let gender: Gender?
    let hostedEvents: [UUID]?
    let participatedEvents: [UUID]?
    let notifications: [UUID]?
    let socialTags: [String]?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case skillLevel = "skill_level"
        case gender
        case hostedEvents = "hosted_events"
        case participatedEvents = "participated_events"
        case notifications
        case socialTags = "social_tags"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(skillLevel, forKey: .skillLevel)
        try container.encodeIfPresent(gender, forKey: .gender)
        try container.encodeIfPresent(hostedEvents, forKey: .hostedEvents)
        try container.encodeIfPresent(participatedEvents, forKey: .participatedEvents)
        try container.encodeIfPresent(notifications, forKey: .notifications)
        try container.encodeIfPresent(socialTags, forKey: .socialTags)
    }
}
