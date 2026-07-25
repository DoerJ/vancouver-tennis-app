import Foundation
import SwiftUI

enum Constants {
    static let locationToCourts: [EventCity: [TennisCourt]] = [
        .burnaby: [
            .bcitCourt,
            .bonsorPublicTennisCourts,
            .brentwoodParkTennisCourts,
            .burnabyHeightsParkTennisCourt,
            .burnabyLakeSportsComplexWest,
            .burnabyLakeTennisCourts,
            .burnabyTennisClub,
            .byrneCreekTennisCourts,
            .caribooParkTennisCourts,
            .centralParkCourt,
            .confederationParkTennisCourts,
            .edmondsParkTennisCourts,
            .ernieWinchParkTennisCourts,
            .keswickPark,
            .moodyParkTennisCourt,
            .robertBurnabyParkTennisCourts,
            .sfuTennisCourts,
            .slocanParkPublicTennisCourts,
            .stoneyCreekParkTennisCourts,
            .willingdonHeightsPark
        ],
        .richmond: [
            .blundellParkTennisCourts,
            .kingGeorgeTennisCourts,
            .richmondTennisClub,
            .southarmCourt,
            .stevestonLondonTennisCourts,
            .tennisBCHub,
            .tennisBritishColumbia,
            .thompsonCommunityParkTennisCourts
        ]
    ]

    enum SocialProfile {
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
        static let maximumDisplayedUnreadCount = 99
        static let maximumDisplayedUnreadText = "99+"
        static let maximumMessageLength = 1000
        static let systemMessagePrefix = "__van_tennis_system__ "

        static func eventLeftSystemMessage(displayName: String) -> String {
            "\(systemMessagePrefix)\(displayName) has left the room."
        }

        static func eventJoinedSystemMessage(displayName: String) -> String {
            "\(systemMessagePrefix)\(displayName) has joined the room."
        }

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

    enum StorageKey {
        static let unreadChatCountsByEventID = "van-tennis.unreadChatCountsByEventID"
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
