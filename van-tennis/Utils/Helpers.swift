import Foundation

enum DateFormattingHelper {
    static func eventDateTimeString(from date: Date) -> String {
        eventDateTimeFormatter.string(from: date)
    }

    static func eventDateString(from date: Date) -> String {
        eventDateFormatter.string(from: date)
    }

    static func monthDayString(from date: Date) -> String {
        monthDayFormatter.string(from: date)
    }

    static func fullDateBadgeString(from date: Date) -> String {
        fullDateBadgeFormatter.string(from: date)
    }

    static func timeBadgeString(from date: Date) -> String {
        timeBadgeFormatter.string(from: date)
    }

    static func shortDateTimeString(from date: Date) -> String {
        shortDateTimeFormatter.string(from: date)
    }

    static func timeString(from date: Date) -> String {
        timeFormatter.string(from: date)
    }

    private static let eventDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let eventDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private static let fullDateBadgeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    private static let timeBadgeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private static let shortDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

enum EventTimeDisplayHelper {
    static func upcomingTimeText(startTime: Date, endTime: Date, now: Date) -> String {
        let calendar = Calendar.current

        if startTime <= now && now < endTime {
            return AppContent.string("events.card.inProgress")
        }

        if endTime <= now {
            return AppContent.string("events.card.ended")
        }

        if calendar.isDateInTomorrow(startTime) {
            return AppContent.string("events.card.tomorrow")
        }

        let secondsUntilStart = startTime.timeIntervalSince(now)
        let hoursUntilStart = Int(ceil(secondsUntilStart / 3_600))

        if hoursUntilStart < 24 {
            return AppContent.string(hoursUntilStart == 1 ? "events.card.inHour" : "events.card.inHours", hoursUntilStart)
        }

        let startOfToday = calendar.startOfDay(for: now)
        let startOfEventDay = calendar.startOfDay(for: startTime)
        let daysUntilStart = calendar.dateComponents([.day], from: startOfToday, to: startOfEventDay).day ?? 1
        let displayDays = max(daysUntilStart, 1)

        return AppContent.string(displayDays == 1 ? "events.card.inDay" : "events.card.inDays", displayDays)
    }
}

enum NotificationTimeDisplayHelper {
    static func relativeCreatedAtText(_ createdAt: Date?, now: Date) -> String {
        guard let createdAt else {
            return AppContent.string("notifications.unknownTime")
        }

        let calendar = Calendar.current

        if calendar.isDateInYesterday(createdAt) {
            return AppContent.string("notifications.yesterday")
        }

        let components = calendar.dateComponents(
            [.year, .month, .weekOfYear, .day, .hour, .minute],
            from: createdAt,
            to: now
        )

        if let years = components.year, years > 0 {
            return AppContent.string(years == 1 ? "notifications.relativeTime.year" : "notifications.relativeTime.years", years)
        }

        if let months = components.month, months > 0 {
            return AppContent.string(months == 1 ? "notifications.relativeTime.month" : "notifications.relativeTime.months", months)
        }

        if let weeks = components.weekOfYear, weeks > 0 {
            return AppContent.string(weeks == 1 ? "notifications.relativeTime.week" : "notifications.relativeTime.weeks", weeks)
        }

        if let days = components.day, days > 0 {
            return AppContent.string(days == 1 ? "notifications.relativeTime.day" : "notifications.relativeTime.days", days)
        }

        if let hours = components.hour, hours > 0 {
            return AppContent.string(hours == 1 ? "notifications.relativeTime.hour" : "notifications.relativeTime.hours", hours)
        }

        if let minutes = components.minute, minutes > 0 {
            return AppContent.string(minutes == 1 ? "notifications.relativeTime.minute" : "notifications.relativeTime.minutes", minutes)
        }

        return AppContent.string("notifications.justNow")
    }
}

enum GenderDisplayHelper {
    static func iconName(for gender: Gender?) -> String {
        switch gender {
        case .male:
            return "face_male"
        case .female:
            return "face_female"
        case .nonBinary, .preferNotToSay, nil:
            return "face_non_binary"
        }
    }

    static func socialTagsLabel(for gender: Gender?) -> String {
        switch gender {
        case .male:
            return AppContent.string("joinRequest.hisTags")
        case .female:
            return AppContent.string("joinRequest.herTags")
        case .nonBinary, .preferNotToSay, nil:
            return AppContent.string("joinRequest.theirTags")
        }
    }
}

enum FilterDisplayHelper {
    static func selectedTitle(defaultTitle: String, selectedTitle: String, allTitle: String) -> String {
        selectedTitle == allTitle ? defaultTitle : selectedTitle
    }
}

enum ProfileDisplayHelper {
    static func displayName(_ displayName: String, fallback: String, suffix: String? = nil) -> String {
        let title = displayName.isEmpty ? fallback : displayName

        guard let suffix else {
            return title
        }

        return "\(title) \(suffix)"
    }
}
