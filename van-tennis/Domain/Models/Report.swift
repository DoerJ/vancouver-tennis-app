import Foundation

enum ReportReason: String, CaseIterable, Codable, Identifiable {
    case harassment
    case languageAbuse = "language_abuse"

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .harassment:
            return "Harassment"
        case .languageAbuse:
            return "Language Abuse"
        }
    }
}

struct Report: Codable, Identifiable, Equatable {
    let id: UUID
    let reporterID: UUID
    let reportedUserID: UUID?
    let reportedEventID: UUID?
    let reason: ReportReason
    let details: String?
    let status: String
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case reporterID = "reporter_id"
        case reportedUserID = "reported_user_id"
        case reportedEventID = "reported_event_id"
        case reason
        case details
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct NewReport: Encodable {
    let reporterID: UUID
    let reportedUserID: UUID?
    let reportedEventID: UUID?
    let reason: ReportReason
    let details: String?

    enum CodingKeys: String, CodingKey {
        case reporterID = "reporter_id"
        case reportedUserID = "reported_user_id"
        case reportedEventID = "reported_event_id"
        case reason
        case details
    }
}
