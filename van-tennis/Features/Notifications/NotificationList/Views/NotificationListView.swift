import SwiftUI

struct NotificationListView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = NotificationListViewModel()
    @State private var selectedJoinRequest: NotificationEvent?
    @State private var pendingJoinRequestNotificationID: UUID?
    let onOpenProfile: () -> Void
    let initialJoinRequestNotificationID: UUID?

    init(
        initialJoinRequestNotificationID: UUID? = nil,
        onOpenProfile: @escaping () -> Void = {}
    ) {
        self.initialJoinRequestNotificationID = initialJoinRequestNotificationID
        self.onOpenProfile = onOpenProfile
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white
                    .ignoresSafeArea()

                if viewModel.isLoading && viewModel.notifications.isEmpty {
                    ProgressView(AppContent.string("notifications.loading"))
                        .rallyLoadingStatusStyle()
                } else if let errorMessage = viewModel.errorMessage, viewModel.notifications.isEmpty {
                    ContentUnavailableView(
                        AppContent.string("notifications.unableToLoad"),
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else {
                    VStack(spacing: 0) {
                        notificationsHeader
                            .padding(.horizontal, 28)
                            .padding(.top, 18)

                        ScrollView {
                            LazyVStack(spacing: 0) {
                                if viewModel.notifications.isEmpty {
                                    emptyNotificationsView
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 80)
                                } else {
                                    ForEach(Array(viewModel.notifications.enumerated()), id: \.element.id) { index, notification in
                                        VStack(spacing: 0) {
                                            NotificationCardView(
                                                notification: notification,
                                                isRead: appState.isCachedNotificationRead(notification.id),
                                                isDeleting: viewModel.deletingNotificationIDs.contains(notification.id),
                                                isMarkingRead: viewModel.markingReadNotificationIDs.contains(notification.id),
                                                allowsSwipeToDelete: notification.notificationType != .eventJoined,
                                                allowsSwipeToMarkRead: !appState.isCachedNotificationRead(notification.id),
                                                onTap: tapAction(for: notification),
                                                onMarkRead: {
                                                    Task {
                                                        let didMarkNotificationRead = await viewModel.markNotificationRead(
                                                            notification,
                                                            currentUserID: appState.userProfile?.id
                                                        )

                                                        if didMarkNotificationRead {
                                                            appState.markCachedNotificationRead(notification.id)
                                                        }
                                                    }
                                                },
                                                onDelete: {
                                                    Task {
                                                        let didDeleteNotification = await viewModel.deleteNotification(
                                                            notification,
                                                            currentUserID: appState.userProfile?.id
                                                        )

                                                        if didDeleteNotification {
                                                            appState.removeCachedNotification(notification.id)
                                                        }
                                                    }
                                                }
                                            )
                                            .padding(.top, index == 0 ? 0 : 14)

                                            if index < viewModel.notifications.count - 1 {
                                                notificationsDivider
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.top, 34)
                            .frame(maxWidth: .infinity)
                        }
                        // .refreshable wrapper task can be cancelled by SwiftUI, the actual notification fetch is now owned by view model
                        .refreshable {
                            viewModel.refreshNotifications(appState: appState, showsLoading: viewModel.notifications.isEmpty)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedJoinRequest) { notification in
                ReviewParticipantJoinRequestView(notification: notification)
            }
        }
        .onChange(of: selectedJoinRequest) { _, notification in
            guard notification == nil else {
                return
            }

            Task {
                await viewModel.loadNotifications(appState: appState, showsLoading: false)
            }
        }
        .onAppear {
            Task {
                await viewModel.loadNotifications(appState: appState, showsLoading: true)
                await openPendingJoinRequestIfNeeded()
            }
        }
        .onChange(of: initialJoinRequestNotificationID) { _, notificationID in
            pendingJoinRequestNotificationID = notificationID

            Task {
                await openPendingJoinRequestIfNeeded()
            }
        }
    }

    private var notificationsHeader: some View {
        VStack(alignment: .leading, spacing: 34) {
            Color.clear
                .frame(width: 40, height: 40)

            Text(AppContent.string("notifications.title"))
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(RallyDiscoverStyle.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyNotificationsView: some View {
        RallyEmptyState(
            iconName: "Bell",
            title: AppContent.string("notifications.empty.title"),
            description: AppContent.string("notifications.empty.description")
        )
    }

    private var notificationsDivider: some View {
        RallyDivider(width: 301)
    }

    private func tapAction(for notification: NotificationEvent) -> (() -> Void)? {
        guard notification.notificationType == .eventJoined else {
            return nil
        }

        return {
            selectedJoinRequest = notification
        }
    }

    private func openPendingJoinRequestIfNeeded() async {
        let notificationID = pendingJoinRequestNotificationID ?? initialJoinRequestNotificationID

        guard let notificationID else {
            return
        }

        guard let notification = await viewModel.notification(id: notificationID),
              notification.notificationType == .eventJoined else {
            pendingJoinRequestNotificationID = nil
            return
        }

        pendingJoinRequestNotificationID = nil
        selectedJoinRequest = notification
    }
}

#Preview {
    NotificationListView()
        .environmentObject(AppState())
}
