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
