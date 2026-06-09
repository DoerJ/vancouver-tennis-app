import SwiftUI

struct MainTabView: View {
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

            NotificationListView()
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }

            UserProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
    }
}

#Preview {
    MainTabView()
}
