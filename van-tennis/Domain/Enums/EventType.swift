enum EventType: String, CaseIterable, Codable, Identifiable {
    case practice
    case casual
    case match

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .practice:
            return "Practice"
        case .casual:
            return "Casual"
        case .match:
            return "Match"
        }
    }
}
