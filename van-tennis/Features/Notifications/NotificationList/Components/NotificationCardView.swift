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
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(RallyDiscoverStyle.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(role: .destructive, action: onDelete) {
                    if isDeleting {
                        ProgressView()
                    } else {
                        Image("delete")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                    }
                }
                .disabled(isDeleting)
                .buttonStyle(.borderless)
                .accessibilityLabel(AppContent.string("notifications.deleteAccessibility"))
            }

            TimelineView(.periodic(from: Date(), by: 60)) { context in
                Label(
                    NotificationTimeDisplayHelper.relativeCreatedAtText(notification.createdAt, now: context.date),
                    systemImage: "clock"
                )
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RallyDiscoverStyle.mutedText)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(Color.white)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
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
