import SwiftUI

struct NotificationCardView: View {
    let notification: NotificationEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(notification.body)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Label(createdAtText, systemImage: "clock")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var createdAtText: String {
        guard let createdAt = notification.createdAt else {
            return "Unknown time"
        }

        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInYesterday(createdAt) {
            return "Yesterday"
        }

        let components = calendar.dateComponents(
            [.year, .month, .weekOfYear, .day, .hour],
            from: createdAt,
            to: now
        )

        if let years = components.year, years > 0 {
            return "\(years) \(years == 1 ? "year" : "years") ago"
        }

        if let months = components.month, months > 0 {
            return "\(months) \(months == 1 ? "month" : "months") ago"
        }

        if let weeks = components.weekOfYear, weeks > 0 {
            return "\(weeks) \(weeks == 1 ? "week" : "weeks") ago"
        }

        if let days = components.day, days > 0 {
            return "\(days) \(days == 1 ? "day" : "days") ago"
        }

        if let hours = components.hour, hours > 0 {
            return "\(hours) \(hours == 1 ? "hour" : "hours") ago"
        }

        return "Just now"
    }
}

#Preview {
    NotificationCardView(
        notification: NotificationEvent(
            id: UUID(),
            sender: UUID(),
            recipients: [UUID()],
            notificationType: .eventJoined,
            title: "Player wants to join your event",
            body: "Alex wants to join your event at Central Park Court.",
            relatedEventID: UUID(),
            readBy: [],
            createdAt: Date(),
            updatedAt: nil
        )
    )
    .padding()
}
