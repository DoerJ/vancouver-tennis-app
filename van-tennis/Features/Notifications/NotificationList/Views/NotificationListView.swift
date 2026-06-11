import SwiftUI

struct NotificationListView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = NotificationListViewModel()
    @State private var selectedJoinRequest: NotificationEvent?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.notifications.isEmpty {
                    ProgressView("Loading notifications")
                } else if let errorMessage = viewModel.errorMessage, viewModel.notifications.isEmpty {
                    ContentUnavailableView(
                        "Unable to load notifications",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else {
                    VStack(spacing: 0) {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                if viewModel.notifications.isEmpty {
                                    ContentUnavailableView(
                                        "No notifications",
                                        systemImage: "bell",
                                        description: Text("Event updates and match activity will appear here.")
                                    )
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 80)
                                } else {
                                    ForEach(viewModel.notifications) { notification in
                                        NotificationCardView(
                                            notification: notification,
                                            isDeleting: viewModel.deletingNotificationIDs.contains(notification.id),
                                            onTap: tapAction(for: notification)
                                        ) {
                                            Task {
                                                await viewModel.deleteNotification(
                                                    notification,
                                                    currentUserID: appState.userProfile?.id
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        }
                        // .refreshable wrapper task can be cancelled by SwiftUI, the actual notification fetch is now owned by view model
                        .refreshable {
                            refreshNotifications(showsLoading: viewModel.notifications.isEmpty)
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
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

    private func loadNotifications(showsLoading: Bool) async {
        await viewModel.loadNotifications(
            currentUserID: appState.userProfile?.id,
            showsLoading: showsLoading
        )
    }

    private func refreshNotifications(showsLoading: Bool) {
        viewModel.refreshNotifications(
            currentUserID: appState.userProfile?.id,
            showsLoading: showsLoading
        )
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
