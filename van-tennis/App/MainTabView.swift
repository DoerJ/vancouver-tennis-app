import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: MainTab = .find
    @State private var findResetTrigger = 0
    @State private var isShowingProfile = false

    var body: some View {
        TabView(selection: tabSelection) {
            EventDiscoveryListView(resetTrigger: findResetTrigger) {
                isShowingProfile = true
            }
                .tabItem {
                    Label("Find", systemImage: "magnifyingglass")
                }
                .tag(MainTab.find)

            MyEventsView {
                isShowingProfile = true
            }
                .tabItem {
                    Label("My Events", systemImage: "calendar")
                }
                .badge(hasMyEvents ? "" : nil)
                .tag(MainTab.myEvents)

            NotificationListView {
                isShowingProfile = true
            }
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }
                .badge(hasNotifications ? "" : nil)
                .tag(MainTab.notifications)

            ChatView {
                isShowingProfile = true
            }
                .tabItem {
                    Label("Chat", systemImage: "message")
                }
                .tag(MainTab.chat)
        }
        .sheet(isPresented: $isShowingProfile) {
            UserProfileView()
                .environmentObject(appState)
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
    case chat
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
}
