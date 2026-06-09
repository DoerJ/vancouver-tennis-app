import SwiftUI

struct NotificationListView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No notifications",
                systemImage: "bell",
                description: Text("Event updates and match activity will appear here.")
            )
            .navigationTitle("Notifications")
        }
    }
}

#Preview {
    NotificationListView()
}
