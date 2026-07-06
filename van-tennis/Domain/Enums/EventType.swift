enum EventType: String, CaseIterable, Codable, Identifiable, Hashable {
    case practice
    case casual
    case match

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .practice:
            return AppContent.string("events.types.practice")
        case .casual:
            return AppContent.string("events.types.casual")
        case .match:
            return AppContent.string("events.types.match")
        }
    }
}
