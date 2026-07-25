import SwiftUI

struct NotificationCardView: View {
    let notification: NotificationEvent
    let isRead: Bool
    let isDeleting: Bool
    let isMarkingRead: Bool
    let allowsSwipeToDelete: Bool
    let allowsSwipeToMarkRead: Bool
    let onTap: (() -> Void)?
    let onMarkRead: () -> Void
    let onDelete: () -> Void
    @State private var horizontalOffset: CGFloat = 0

    init(
        notification: NotificationEvent,
        isRead: Bool = true,
        isDeleting: Bool = false,
        isMarkingRead: Bool = false,
        allowsSwipeToDelete: Bool = true,
        allowsSwipeToMarkRead: Bool = false,
        onTap: (() -> Void)? = nil,
        onMarkRead: @escaping () -> Void = {},
        onDelete: @escaping () -> Void = {}
    ) {
        self.notification = notification
        self.isRead = isRead
        self.isDeleting = isDeleting
        self.isMarkingRead = isMarkingRead
        self.allowsSwipeToDelete = allowsSwipeToDelete
        self.allowsSwipeToMarkRead = allowsSwipeToMarkRead
        self.onTap = onTap
        self.onMarkRead = onMarkRead
        self.onDelete = onDelete
    }

    var body: some View {
        ZStack {
            markReadBackground
            deleteBackground

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    unreadIndicator
                        .padding(.top, 7)

                    Text(notification.body)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(RallyDiscoverStyle.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                TimelineView(.periodic(from: Date(), by: 60)) { context in
                    Label(
                        NotificationTimeDisplayHelper.relativeCreatedAtText(notification.createdAt, now: context.date),
                        systemImage: "clock"
                    )
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(RallyDiscoverStyle.mutedText)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .background(Color.white)
            .opacity(isDeleting || isMarkingRead ? 0.45 : 1)
            .offset(x: horizontalOffset)
            .contentShape(Rectangle())
            .gesture(allowsSwipeToDelete || allowsSwipeToMarkRead ? notificationSwipeGesture : nil)
            .onTapGesture {
                onTap?()
            }
        }
        .clipped()
    }

    private var markReadBackground: some View {
        HStack {
            Image("mark_email_read")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .padding(.leading, 22)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 51.0 / 255.0, green: 92.0 / 255.0, blue: 31.0 / 255.0))
        .opacity(markReadBackgroundOpacity)
    }

    private var deleteBackground: some View {
        HStack {
            Spacer()

            Image("delete_white")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .padding(.trailing, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RallyDiscoverStyle.redBadge)
        .opacity(deleteBackgroundOpacity)
    }

    @ViewBuilder
    private var unreadIndicator: some View {
        if !isRead {
            Circle()
                .fill(Color(red: 0.57, green: 0.66, blue: 0.34))
                .frame(width: 8, height: 8)
        }
    }

    private var deleteBackgroundOpacity: Double {
        guard allowsSwipeToDelete, horizontalOffset < 0 else {
            return 0
        }

        let swipeDistance = min(abs(horizontalOffset), UIScreen.main.bounds.width)
        return max(0.18, 1 - (swipeDistance / UIScreen.main.bounds.width))
    }

    private var markReadBackgroundOpacity: Double {
        guard allowsSwipeToMarkRead, horizontalOffset > 0 else {
            return 0
        }

        let swipeDistance = min(abs(horizontalOffset), UIScreen.main.bounds.width)
        return max(0.18, 1 - (swipeDistance / UIScreen.main.bounds.width))
    }

    private var notificationSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                guard !isDeleting,
                      !isMarkingRead,
                      abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }

                if value.translation.width < 0, allowsSwipeToDelete {
                    horizontalOffset = min(0, max(value.translation.width, -UIScreen.main.bounds.width))
                } else if value.translation.width > 0, allowsSwipeToMarkRead {
                    horizontalOffset = max(0, min(value.translation.width, UIScreen.main.bounds.width))
                } else {
                    horizontalOffset = 0
                }
            }
            .onEnded { value in
                guard !isDeleting, !isMarkingRead else {
                    horizontalOffset = 0
                    return
                }

                if value.translation.width <= -82, allowsSwipeToDelete {
                    withAnimation(.easeOut(duration: 0.16)) {
                        horizontalOffset = -UIScreen.main.bounds.width
                    }
                    onDelete()
                } else if value.translation.width >= 82, allowsSwipeToMarkRead {
                    onMarkRead()
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                        horizontalOffset = 0
                    }
                } else {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                        horizontalOffset = 0
                    }
                }
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
