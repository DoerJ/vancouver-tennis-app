import Foundation
import SwiftUI

enum Constants {
    struct TennisCourtDistrictGroup: Identifiable {
        let district: String
        let courts: [TennisCourt]

        var id: String {
            district
        }
    }

    static let locationToCourts: [EventCity: [TennisCourt]] = [
        .burnaby: [
            .bcitCourt,
            .bonsorPublicTennisCourts,
            .brentwoodParkTennisCourts,
            .broadviewPark,
            .burnabyHeightsParkTennisCourt,
            .burnabyLakeSportsComplexWest,
            .burnabyLakeTennisCourts,
            .burnabySouthMemorialPark,
            .burnabyTennisClub,
            .byrneCreekTennisCourts,
            .caribooParkTennisCourts,
            .centralParkCourt,
            .confederationParkTennisCourts,
            .davidGrayPark,
            .eastGrovePark,
            .edmondsParkTennisCourts,
            .ernieWinchParkTennisCourts,
            .forestGrovePark,
            .kensingtonPark,
            .keswickPark,
            .louMoroPark,
            .maryAvenuePark,
            .maywoodSchoolSite,
            .moodyParkTennisCourt,
            .robertBurnabyParkTennisCourts,
            .ronMcLeanPark,
            .sfuTennisCourts,
            .slocanParkPublicTennisCourts,
            .squintLakePark,
            .stoneyCreekParkTennisCourts,
            .willingdonHeightsPark
        ],
        .richmond: [
            .blundellParkTennisCourts,
            .burkevilleNeighbourhoodPark,
            .doverNeighbourhoodPark,
            .gardenCityNeighbourhoodPark,
            .hamiltonCommunityPark,
            .hughBoydCommunityPark,
            .katsuraNeighbourhoodPark,
            .kingGeorgeTennisCourts,
            .mcNairNeighbourhoodPark,
            .minoruPark,
            .odlinNeighbourhoodPark,
            .odlinwoodNeighbourhoodPark,
            .rcPalmerSecondarySchool,
            .richmondTennisClub,
            .southarmCourt,
            .stevestonCommunityPark,
            .stevestonLondonTennisCourts,
            .tennisBCHub,
            .tennisBritishColumbia,
            .terraNovaNeighbourhoodPark,
            .thompsonCommunityParkTennisCourts
        ],
        .surrey: [
            .alderwoodPark,
            .bellPark,
            .bobRutledgePark,
            .bridgeviewPark,
            .claytonPark,
            .cloverdaleAthleticPark,
            .cloverdaleHeightsPark,
            .crescentPark,
            .douglasPark,
            .fleetwoodPark,
            .fraserHeightsPark,
            .goldstonePark,
            .hazelgrovePark,
            .hummingbirdPark,
            .kennedyPark,
            .mapleGreenPark,
            .meridianByTheSea,
            .morganCreekPark,
            .newtonAthleticPark,
            .robsonPark,
            .royalKwantlenPark,
            .southSurreyAthleticPark,
            .sullivanPark,
            .sunnysidePark
        ],
        .vancouver: [
            .almondPark,
            .andyLivingstonePark,
            .brewersPark,
            .burrardViewPark,
            .captainCookPark,
            .champlainHeightsPark,
            .charlesonPark,
            .clarkPark,
            .davidLamPark,
            .eburnePark,
            .elmPark,
            .gardenPark,
            .granvilleLoopPark,
            .granvillePark,
            .graysPark,
            .guelphPark,
            .hastingsCommunityPark,
            .heatherPark,
            .hummPark,
            .jerichoBeachPark,
            .johnHendryTroutLakePark,
            .kasloPark,
            .kitsilanoBeachPark,
            .langaraGolfCourse,
            .macDonaldPark,
            .mcBridePark,
            .mcSpaddenPark,
            .melbournePark,
            .memorialSouthPark,
            .memorialWestPark,
            .moberlyPark,
            .oakPark,
            .pandoraPark,
            .queenElizabethPark,
            .riverfrontPark,
            .rupertPark,
            .stanleyPark,
            .strathconaPark,
            .sutcliffePark,
            .tatlowPark,
            .vancouverRobsonPark,
            .vancouverSlocanPark,
            .westPointGreyPark
        ]
    ]

    static let surreyCourtDistrictGroups: [TennisCourtDistrictGroup] = [
        TennisCourtDistrictGroup(
            district: AppContent.string("events.districts.cloverdale"),
            courts: [
                .claytonPark,
                .cloverdaleAthleticPark,
                .cloverdaleHeightsPark,
                .hazelgrovePark
            ]
        ),
        TennisCourtDistrictGroup(
            district: AppContent.string("events.districts.fleetwood"),
            courts: [
                .fleetwoodPark,
                .mapleGreenPark
            ]
        ),
        TennisCourtDistrictGroup(
            district: AppContent.string("events.districts.guildford"),
            courts: [
                .douglasPark,
                .fraserHeightsPark,
                .hummingbirdPark
            ]
        ),
        TennisCourtDistrictGroup(
            district: AppContent.string("events.districts.newton"),
            courts: [
                .bobRutledgePark,
                .goldstonePark,
                .newtonAthleticPark,
                .sullivanPark
            ]
        ),
        TennisCourtDistrictGroup(
            district: AppContent.string("events.districts.northSurrey"),
            courts: [
                .bridgeviewPark,
                .kennedyPark,
                .robsonPark,
                .royalKwantlenPark
            ]
        ),
        TennisCourtDistrictGroup(
            district: AppContent.string("events.districts.southSurrey"),
            courts: [
                .alderwoodPark,
                .bellPark,
                .crescentPark,
                .meridianByTheSea,
                .morganCreekPark,
                .southSurreyAthleticPark,
                .sunnysidePark
            ]
        )
    ]

    static let vancouverCourtDistrictGroups: [TennisCourtDistrictGroup] = [
        TennisCourtDistrictGroup(
            district: AppContent.string("events.districts.downtown"),
            courts: [
                .andyLivingstonePark,
                .davidLamPark
            ]
        ),
        TennisCourtDistrictGroup(
            district: AppContent.string("events.districts.dunbarSouthlands"),
            courts: [
                .memorialWestPark
            ]
        ),
        TennisCourtDistrictGroup(
            district: AppContent.string("events.districts.fairview"),
            courts: [
                .charlesonPark,
                .granvilleLoopPark,
                .granvillePark,
                .sutcliffePark
            ]
        ),
        TennisCourtDistrictGroup(
            district: AppContent.string("events.districts.grandviewWoodland"),
            courts: [
                .gardenPark,
                .mcSpaddenPark,
                .pandoraPark
            ]
        ),
        TennisCourtDistrictGroup(
            district: AppContent.string("events.districts.hastingsSunrise"),
            courts: [
                .burrardViewPark,
                .hastingsCommunityPark,
                .kasloPark,
                .rupertPark
            ]
        ),
        TennisCourtDistrictGroup(
            district: AppContent.string("events.districts.kensingtonCedarCottage"),
            courts: [
                .brewersPark,
                .clarkPark,
                .graysPark,
                .johnHendryTroutLakePark
            ]
        ),
        TennisCourtDistrictGroup(
            district: AppContent.string("events.districts.kerrisdale"),
            courts: [
                .elmPark
            ]
        ),
        TennisCourtDistrictGroup(
            district: AppContent.string("events.districts.killarney"),
            courts: [
                .captainCookPark,
                .champlainHeightsPark,
                .riverfrontPark
            ]
        ),
        TennisCourtDistrictGroup(
            district: AppContent.string("events.districts.kitsilano"),
            courts: [
                .almondPark,
                .kitsilanoBeachPark,
                .mcBridePark,
                .tatlowPark
            ]
        ),
        TennisCourtDistrictGroup(
            district: AppContent.string("events.districts.marpole"),
            courts: [
                .eburnePark,
                .oakPark
            ]
        ),
        TennisCourtDistrictGroup(
            district: AppContent.string("events.districts.mountPleasant"),
            courts: [
                .guelphPark,
                .vancouverRobsonPark
            ]
        ),
        TennisCourtDistrictGroup(
            district: AppContent.string("events.districts.renfrewCollingwood"),
            courts: [
                .melbournePark,
                .vancouverSlocanPark
            ]
        ),
        TennisCourtDistrictGroup(
            district: AppContent.string("events.districts.rileyLittleMountain"),
            courts: [
                .queenElizabethPark
            ]
        ),
        TennisCourtDistrictGroup(
            district: AppContent.string("events.districts.southCambie"),
            courts: [
                .heatherPark,
                .langaraGolfCourse
            ]
        ),
        TennisCourtDistrictGroup(
            district: AppContent.string("events.districts.strathcona"),
            courts: [
                .strathconaPark
            ]
        ),
        TennisCourtDistrictGroup(
            district: AppContent.string("events.districts.sunset"),
            courts: [
                .macDonaldPark,
                .memorialSouthPark,
                .moberlyPark
            ]
        ),
        TennisCourtDistrictGroup(
            district: AppContent.string("events.districts.victoriaFraserview"),
            courts: [
                .hummPark
            ]
        ),
        TennisCourtDistrictGroup(
            district: AppContent.string("events.districts.westEnd"),
            courts: [
                .stanleyPark
            ]
        ),
        TennisCourtDistrictGroup(
            district: AppContent.string("events.districts.westPointGrey"),
            courts: [
                .jerichoBeachPark,
                .westPointGreyPark
            ]
        )
    ]

    static func courtDisplayName(for court: TennisCourt, in city: EventCity) -> String {
        guard let district = courtDistrict(for: court, in: city) else {
            return court.displayName
        }

        return "\(district) - \(court.displayName)"
    }

    static func defaultCourt(for city: EventCity) -> TennisCourt? {
        if let firstGroupedCourt = courtDistrictGroups(for: city)
            .compactMap({ $0.courts.first })
            .first {
            return firstGroupedCourt
        }

        return city.courts.first
    }

    static func courtDistrict(for court: TennisCourt, in city: EventCity) -> String? {
        courtDistrictGroups(for: city)
            .first { $0.courts.contains(court) }?
            .district
    }

    static func courtDistrictGroups(for city: EventCity) -> [TennisCourtDistrictGroup] {
        switch city {
        case .surrey:
            return surreyCourtDistrictGroups
        case .vancouver:
            return vancouverCourtDistrictGroups
        case .burnaby, .richmond:
            return []
        }
    }

    enum SocialProfile {
        static let maximumSelectedTags = 5

        static let tagOptions = [
            "Friendly",
            "Engineer",
            "Just for Fun",
            "Competitive",
            "New to City",
            "Patient",
            "Designer",
            "Social",
            "Remote Worker",
            "Beginner-Friendly",
            "Finance",
            "Chill",
            "Founder",
            "High Energy",
            "Healthcare",
            "Quiet",
            "Product",
            "Open-Minded",
            "Student",
            "Education"
        ]
    }

    enum SkillLevelStyle {
        static func description(for skillLevel: SkillLevel) -> String {
            switch skillLevel {
            case .one:
                return AppContent.string("auth.onboarding.skillDescriptions.one")
            case .oneFive:
                return AppContent.string("auth.onboarding.skillDescriptions.oneFive")
            case .two:
                return AppContent.string("auth.onboarding.skillDescriptions.two")
            case .twoFive:
                return AppContent.string("auth.onboarding.skillDescriptions.twoFive")
            case .three:
                return AppContent.string("auth.onboarding.skillDescriptions.three")
            case .threeFive:
                return AppContent.string("auth.onboarding.skillDescriptions.threeFive")
            case .four:
                return AppContent.string("auth.onboarding.skillDescriptions.four")
            }
        }

        static func badgeColor(for skillLevel: SkillLevel) -> Color {
            switch skillLevel {
            case .one:
                return Color(hex: 0x91A857)
            case .oneFive:
                return Color(hex: 0x335C1F)
            case .two:
                return Color(hex: 0xF2DB21)
            case .twoFive:
                return Color(hex: 0xFFA300)
            case .three:
                return Color(hex: 0xF27B35)
            case .threeFive:
                return Color(hex: 0xFA4720)
            case .four:
                return Color(hex: 0xFA2020)
            }
        }

        static func badgeColor(for skillLevel: SkillLevel?) -> Color {
            guard let skillLevel else {
                return RallyDiscoverStyle.mutedText
            }

            return badgeColor(for: skillLevel)
        }
    }

    enum EventTypeStyle {
        static func badgeColor(for eventType: EventType) -> Color {
            switch eventType {
            case .practice:
                return Color(hex: 0x91A857)
            case .casual:
                return Color(hex: 0xF2DB21)
            case .match:
                return Color(hex: 0xFFA300)
            }
        }
    }

    enum Event {
        static let creationWindowDays = 7
        static let minimumPlayerLimit = 2
        static let maximumPlayerLimit = 6
        static let minimumStartOffsetHours = 1
        static let minimumDurationMinutes = 30
        static let maximumDurationHours = 3
        static let defaultStartOffsetHours = 2
        static let defaultDurationHours = 1
    }

    enum EventDiscovery {
        static let pageSize = 10
        static let paginationTriggerDistance: CGFloat = 80
        static let cardTimelineRefreshInterval: TimeInterval = 60
    }

    enum Chat {
        static let messageNotificationType = "chat_message_received"
        static let maximumMessageLength = 1000
        static let subscribeTimeoutNanoseconds: UInt64 = 10_000_000_000
        static let systemMessagePrefix = "__van_tennis_system__ "

        static func displayBody(for messageBody: String) -> String {
            guard messageBody.hasPrefix(systemMessagePrefix) else {
                return messageBody
            }

            return String(messageBody.dropFirst(systemMessagePrefix.count))
        }

        static func isSystemMessage(_ messageBody: String) -> Bool {
            messageBody.hasPrefix(systemMessagePrefix)
        }
    }

    enum Realtime {
        static let profileHealthMonitorIntervalNanoseconds: UInt64 = 180_000_000_000
        static let profileRecoveryGraceIntervalNanoseconds: UInt64 = 8_000_000_000
        static let profileRetryBaseIntervalNanoseconds: UInt64 = 1_000_000_000
        static let profileRetryMaximumExponent = 4
    }

}

private extension Color {
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}
