import Foundation

enum Constants {
    static let locationToCourts: [EventCity: [TennisCourt]] = [
        .burnaby: [.bcitCourt, .centralParkCourt],
        .richmond: [.southarmCourt]
    ]

    enum SocialProfile {
        static let tagOptions = ["intj", "enfp", "software engineer"]
    }

    enum Event {
        static let creationWindowDays = 3
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
