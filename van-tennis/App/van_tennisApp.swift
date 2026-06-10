import SwiftUI

@main
struct van_tennisApp: App {
    // Notification service is attached to app, and asks for notification permissions on app launch.
    @UIApplicationDelegateAdaptor(NotificationService.self) private var notificationService
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}
