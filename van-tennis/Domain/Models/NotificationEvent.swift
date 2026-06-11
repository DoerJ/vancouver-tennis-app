import Foundation

enum NotificationType: String, CaseIterable, Codable, Identifiable {
    case eventJoined = "event_joined"
    case eventCanceled = "event_canceled"
    case eventUpdated = "event_updated"
    case approveJoinRequest = "approve_join_request"
    case rejectJoinRequest = "reject_join_request"

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .eventJoined:
            return "Event Joined"
        case .eventCanceled:
            return "Event Canceled"
        case .eventUpdated:
            return "Event Updated"
        case .approveJoinRequest:
            return "Join Request Approved"
        case .rejectJoinRequest:
            return "Join Request Rejected"
        }
    }
}

struct NotificationEvent: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let sender: UUID
    let recipients: [UUID]
    let notificationType: NotificationType
    let title: String
    let body: String
    let relatedEventID: UUID?
    // One notification could be sent to multiple recipients
    let readBy: [UUID]
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case sender
        case recipients
        case notificationType = "notification_type"
        case title
        case body
        case relatedEventID = "related_event_id"
        case readBy = "read_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func isRead(by userID: UUID) -> Bool {
        readBy.contains(userID)
    }
}

struct NewNotificationEvent: Encodable {
    let sender: UUID
    let recipients: [UUID]
    let notificationType: NotificationType
    let title: String
    let body: String
    let relatedEventID: UUID?

    enum CodingKeys: String, CodingKey {
        case sender
        case recipients
        case notificationType = "notification_type"
        case title
        case body
        case relatedEventID = "related_event_id"
    }
}

struct UpdateNotificationEvent: Encodable {
    let readBy: [UUID]?

    enum CodingKeys: String, CodingKey {
        case readBy = "read_by"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(readBy, forKey: .readBy)
    }
}
