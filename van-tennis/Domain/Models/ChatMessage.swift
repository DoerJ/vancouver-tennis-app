import Foundation

struct ChatMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let eventID: UUID
    let senderID: UUID
    let body: String
    let createdAt: Date
    let editedAt: Date?
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case eventID = "event_id"
        case senderID = "sender_id"
        case body
        case createdAt = "created_at"
        case editedAt = "edited_at"
        case deletedAt = "deleted_at"
    }
}

struct NewChatMessage: Encodable {
    let eventID: UUID
    let senderID: UUID
    let body: String

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case senderID = "sender_id"
        case body
    }
}

struct ChatRoomMessage: Identifiable, Equatable {
    let id: UUID
    let senderID: UUID
    let senderDisplayName: String
    let senderAvatarURL: URL?
    let body: String
    let sentAt: Date
}
