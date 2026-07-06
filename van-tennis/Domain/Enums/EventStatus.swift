enum EventStatus: String, Codable, Identifiable, Hashable {
    case upcoming
    case inProgress = "in_progress"
    case completed
    case full
    case cancelled

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .upcoming:
            return AppContent.string("events.status.upcoming")
        case .inProgress:
            return AppContent.string("events.status.inProgress")
        case .completed:
            return AppContent.string("events.status.completed")
        case .full:
            return AppContent.string("events.status.full")
        case .cancelled:
            return AppContent.string("events.status.cancelled")
        }
    }
}
