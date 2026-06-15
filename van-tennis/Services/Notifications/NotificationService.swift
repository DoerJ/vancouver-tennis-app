import UIKit
import UserNotifications

final class NotificationService: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /**
        Notification flow:
        1. Supabase trigger fires edge function
        2. Edge function fetches device token for the user to be notified
        3. Edge function sends notification payload to APNs
        4. APNs delivers notification to user's device
    */
    static let deviceTokenDidUpdateNotification = Notification.Name("DeviceTokenDidUpdateNotification")
    static let remoteNotificationDidArriveNotification = Notification.Name("RemoteNotificationDidArriveNotification")
    static private(set) var currentDeviceToken: String?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        requestRemoteNotificationRegistration()
        return true
    }

    func application(
        _ application: UIApplication,
        // APNs returns the device token as Data, which needs to be converted to a hex string for use in the edge function.
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        // The current device token is saved in notification service
        Self.currentDeviceToken = token
        print("NotificationService: registered APNs device token.")

        NotificationCenter.default.post(
            name: Self.deviceTokenDidUpdateNotification,
            object: token
        )
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Self.currentDeviceToken = nil
        print("NotificationService: failed to register for remote notifications: \(error.localizedDescription)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("NotificationService: received remote notification.")
        postRemoteNotificationDidArrive()
        completionHandler(.newData)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        print("NotificationService: received foreground notification.")
        postRemoteNotificationDidArrive()
        return [.banner, .badge, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        print("NotificationService: user opened notification.")
        postRemoteNotificationDidArrive()
    }

    private func requestRemoteNotificationRegistration() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { isGranted, error in
            if let error {
                print("NotificationService: notification permission request failed: \(error.localizedDescription)")
            }

            print("NotificationService: notification permission granted: \(isGranted)")

            // Register with APNs even when alert permission is denied, so the app can still receive a device token.
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    private func postRemoteNotificationDidArrive() {
        NotificationCenter.default.post(
            name: Self.remoteNotificationDidArriveNotification,
            object: nil
        )
    }
}
