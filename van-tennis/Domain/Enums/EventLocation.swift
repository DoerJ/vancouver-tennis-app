enum EventCity: String, CaseIterable, Codable, Identifiable, Hashable {
    case burnaby
    case richmond

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .burnaby:
            return "Burnaby"
        case .richmond:
            return "Richmond"
        }
    }

    var courts: [TennisCourt] {
        switch self {
        case .burnaby:
            return [.bcitCourt, .centralParkCourt]
        case .richmond:
            return [.southarmCourt]
        }
    }
}

enum TennisCourt: String, CaseIterable, Codable, Identifiable, Hashable {
    case bcitCourt
    case centralParkCourt
    case southarmCourt

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .bcitCourt:
            return "BCIT Court"
        case .centralParkCourt:
            return "Central Park Court"
        case .southarmCourt:
            return "Southarm Court"
        }
    }
}
