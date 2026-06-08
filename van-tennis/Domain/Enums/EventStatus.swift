enum EventStatus: String, Codable, Identifiable {
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
            return "Upcoming"
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
        case .full:
            return "Full"
        case .cancelled:
            return "Cancelled"
        }
    }
}
