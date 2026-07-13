import SwiftUI

struct NotificationListView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = NotificationListViewModel()
    @State private var selectedJoinRequest: NotificationEvent?
    let onOpenProfile: () -> Void

    init(onOpenProfile: @escaping () -> Void = {}) {
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
                                                isDeleting: viewModel.deletingNotificationIDs.contains(notification.id),
                                                onTap: tapAction(for: notification)
                                            ) {
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
                            refreshNotifications(showsLoading: viewModel.notifications.isEmpty)
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
                await loadNotifications(showsLoading: false)
            }
        }
        .onAppear {
            Task {
                await loadNotifications(showsLoading: true)
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
        VStack(spacing: 10) {
            Image("Bell")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(RallyDiscoverStyle.ink)
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)

            Text(AppContent.string("notifications.empty.title"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(RallyDiscoverStyle.ink)
                .multilineTextAlignment(.center)

            Text(AppContent.string("notifications.empty.description"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(RallyDiscoverStyle.mutedText)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding(.horizontal, 28)
    }

    private var notificationsDivider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.1))
            .frame(width: 301, height: 1)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private func loadNotifications(showsLoading: Bool) async {
        if let notificationIDs = await viewModel.loadNotifications(
            currentUserID: appState.userProfile?.id,
            showsLoading: showsLoading
        ) {
            appState.updateCachedNotifications(notificationIDs)
        }
    }

    private func refreshNotifications(showsLoading: Bool) {
        viewModel.refreshNotifications(
            currentUserID: appState.userProfile?.id,
            showsLoading: showsLoading
        ) { notificationIDs in
            if let notificationIDs {
                appState.updateCachedNotifications(notificationIDs)
            }
        }
    }

    private func tapAction(for notification: NotificationEvent) -> (() -> Void)? {
        guard notification.notificationType == .eventJoined else {
            return nil
        }

        return {
            selectedJoinRequest = notification
        }
    }
}

#Preview {
    NotificationListView()
        .environmentObject(AppState())
}
