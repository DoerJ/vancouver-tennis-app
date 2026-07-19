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
    case burnabyTennisClub
    case burnabyLakeTennisCourts
    case robertBurnabyParkTennisCourts
    case byrneCreekTennisCourts
    case willingdonHeightsPark
    case keswickPark
    case bonsorPublicTennisCourts
    case stoneyCreekParkTennisCourts
    case caribooParkTennisCourts
    case edmondsParkTennisCourts
    case burnabyHeightsParkTennisCourt
    case burnabyLakeSportsComplexWest
    case brentwoodParkTennisCourts
    case moodyParkTennisCourt
    case confederationParkTennisCourts
    case ernieWinchParkTennisCourts
    case sfuTennisCourts
    case slocanParkPublicTennisCourts
    case blundellParkTennisCourts
    case kingGeorgeTennisCourts
    case richmondTennisClub
    case stevestonLondonTennisCourts
    case tennisBCHub
    case tennisBritishColumbia
    case thompsonCommunityParkTennisCourts
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
        case .burnabyTennisClub:
            return AppContent.string("events.locations.burnabyTennisClub")
        case .burnabyLakeTennisCourts:
            return AppContent.string("events.locations.burnabyLakeTennisCourts")
        case .robertBurnabyParkTennisCourts:
            return AppContent.string("events.locations.robertBurnabyParkTennisCourts")
        case .byrneCreekTennisCourts:
            return AppContent.string("events.locations.byrneCreekTennisCourts")
        case .willingdonHeightsPark:
            return AppContent.string("events.locations.willingdonHeightsPark")
        case .keswickPark:
            return AppContent.string("events.locations.keswickPark")
        case .bonsorPublicTennisCourts:
            return AppContent.string("events.locations.bonsorPublicTennisCourts")
        case .stoneyCreekParkTennisCourts:
            return AppContent.string("events.locations.stoneyCreekParkTennisCourts")
        case .caribooParkTennisCourts:
            return AppContent.string("events.locations.caribooParkTennisCourts")
        case .edmondsParkTennisCourts:
            return AppContent.string("events.locations.edmondsParkTennisCourts")
        case .burnabyHeightsParkTennisCourt:
            return AppContent.string("events.locations.burnabyHeightsParkTennisCourt")
        case .burnabyLakeSportsComplexWest:
            return AppContent.string("events.locations.burnabyLakeSportsComplexWest")
        case .brentwoodParkTennisCourts:
            return AppContent.string("events.locations.brentwoodParkTennisCourts")
        case .moodyParkTennisCourt:
            return AppContent.string("events.locations.moodyParkTennisCourt")
        case .confederationParkTennisCourts:
            return AppContent.string("events.locations.confederationParkTennisCourts")
        case .ernieWinchParkTennisCourts:
            return AppContent.string("events.locations.ernieWinchParkTennisCourts")
        case .sfuTennisCourts:
            return AppContent.string("events.locations.sfuTennisCourts")
        case .slocanParkPublicTennisCourts:
            return AppContent.string("events.locations.slocanParkPublicTennisCourts")
        case .blundellParkTennisCourts:
            return AppContent.string("events.locations.blundellParkTennisCourts")
        case .kingGeorgeTennisCourts:
            return AppContent.string("events.locations.kingGeorgeTennisCourts")
        case .richmondTennisClub:
            return AppContent.string("events.locations.richmondTennisClub")
        case .stevestonLondonTennisCourts:
            return AppContent.string("events.locations.stevestonLondonTennisCourts")
        case .tennisBCHub:
            return AppContent.string("events.locations.tennisBCHub")
        case .tennisBritishColumbia:
            return AppContent.string("events.locations.tennisBritishColumbia")
        case .thompsonCommunityParkTennisCourts:
            return AppContent.string("events.locations.thompsonCommunityParkTennisCourts")
        case .southarmCourt:
            return AppContent.string("events.locations.southarmCourt")
        }
    }
}
