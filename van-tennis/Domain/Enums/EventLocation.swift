enum EventCity: String, CaseIterable, Codable, Identifiable, Hashable {
    case burnaby
    case richmond

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .burnaby:
            return AppContent.string("events.locations.burnaby")
        case .richmond:
            return AppContent.string("events.locations.richmond")
        }
    }

    var courts: [TennisCourt] {
        Constants.locationToCourts[self] ?? []
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
            return AppContent.string("events.locations.bcitCourt")
        case .centralParkCourt:
            return AppContent.string("events.locations.centralParkCourt")
        case .southarmCourt:
            return AppContent.string("events.locations.southarmCourt")
        }
    }
}
