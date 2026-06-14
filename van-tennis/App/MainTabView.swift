import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: MainTab = .find
    @State private var findResetTrigger = 0

    var body: some View {
        TabView(selection: tabSelection) {
            EventDiscoveryListView(resetTrigger: findResetTrigger)
                .tabItem {
                    Label("Find", systemImage: "magnifyingglass")
                }
                .tag(MainTab.find)

            MyEventsView()
                .tabItem {
                    Label("My Events", systemImage: "calendar")
                }
                .badge(hasMyEvents ? "" : nil)
                .tag(MainTab.myEvents)

            NotificationListView()
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }
                .badge(hasNotifications ? "" : nil)
                .tag(MainTab.notifications)

            UserProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(MainTab.profile)
        }
    }

    private var tabSelection: Binding<MainTab> {
        Binding {
            selectedTab
        } set: { newTab in
            selectedTab = newTab

            if newTab == .find {
                findResetTrigger += 1
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

private enum MainTab: Hashable {
    case find
    case myEvents
    case notifications
    case profile
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
}
