import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            EventDiscoveryListView()
                .tabItem {
                    Label("Find", systemImage: "magnifyingglass")
                }

            MyEventsView()
                .tabItem {
                    Label("My Events", systemImage: "calendar")
                }
                .badge(hasMyEvents ? "" : nil)

            NotificationListView()
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }
                .badge(hasNotifications ? "" : nil)

            UserProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
    }

    private var hasMyEvents: Bool {
        guard let profile = appState.userProfile else {
            return false
        }

        return !profile.hostedEvents.isEmpty || !profile.participatedEvents.isEmpty
    }

    private var hasNotifications: Bool {
        guard let profile = appState.userProfile else {
            return false
        }

        return !profile.notifications.isEmpty
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
}
