import SwiftUI

struct NotificationCardView: View {
    let notification: NotificationEvent
    let isDeleting: Bool
    let onTap: (() -> Void)?
    let onDelete: () -> Void

    init(
        notification: NotificationEvent,
        isDeleting: Bool = false,
        onTap: (() -> Void)? = nil,
        onDelete: @escaping () -> Void = {}
    ) {
        self.notification = notification
        self.isDeleting = isDeleting
        self.onTap = onTap
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text(notification.body)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(role: .destructive, action: onDelete) {
                    if isDeleting {
                        ProgressView()
                    } else {
                        Image(systemName: "trash")
                    }
                }
                .disabled(isDeleting)
                .buttonStyle(.borderless)
                .accessibilityLabel(AppContent.string("notifications.deleteAccessibility"))
            }

            TimelineView(.periodic(from: Date(), by: 60)) { context in
                Label(createdAtText(now: context.date), systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            onTap?()
        }
    }

    private func createdAtText(now: Date) -> String {
        guard let createdAt = notification.createdAt else {
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
