import Foundation

enum ReportReason: String, CaseIterable, Codable, Identifiable {
    case harassment
    case languageAbuse = "language_abuse"
    case sexualHarassment = "sexual_harassment"
    case noShowOrAbusiveBehavior = "no_show_or_abusive_behavior"

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .harassment:
            return AppContent.string("reports.reasons.harassment")
        case .languageAbuse:
            return AppContent.string("reports.reasons.languageAbuse")
        case .sexualHarassment:
            return AppContent.string("reports.reasons.sexualHarassment")
        case .noShowOrAbusiveBehavior:
            return AppContent.string("reports.reasons.noShowOrAbusiveBehavior")
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
