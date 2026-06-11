import SwiftUI

struct NotificationListView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = NotificationListViewModel()

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
                } else if viewModel.notifications.isEmpty {
                    ContentUnavailableView(
                        "No notifications",
                        systemImage: "bell",
                        description: Text("Event updates and match activity will appear here.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.notifications) { notification in
                                NotificationCardView(notification: notification)
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await loadNotifications()
                    }
                }
            }
            .navigationTitle("Notifications")
            .onAppear {
                Task {
                    await loadNotifications()
                }
            }
        }
    }

    private func loadNotifications() async {
        await viewModel.loadNotifications(
            currentUserID: appState.userProfile?.id
        )
    }
}

#Preview {
    NotificationListView()
        .environmentObject(AppState())
}
