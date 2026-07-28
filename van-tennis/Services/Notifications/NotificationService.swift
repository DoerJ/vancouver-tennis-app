import UIKit
import UserNotifications

final class NotificationService: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /**
        Notification flow:
        1. Supabase trigger fires edge function
        2. Edge function fetches device token for the user to be notified
        3. Edge function sends notification payload to APNs
        4. APNs delivers notification to user's device
        5. If the user taps the notification, route them to the related app screen
    */
    static let deviceTokenDidUpdateNotification = Notification.Name("DeviceTokenDidUpdateNotification")
    static let remoteNotificationDidOpenNotification = Notification.Name("RemoteNotificationDidOpenNotification")
    static private(set) var currentDeviceToken: String?
    static private(set) var activeChatEventID: UUID?
    static private var isUserSignedIn = false
    static private var pendingOpenedNotificationContext: OpenedNotificationContext?

    struct OpenedNotificationContext {
        let notificationID: UUID?
        let notificationType: NotificationType?
        let rawNotificationType: String?
        let relatedEventID: UUID?
    }

    static func setActiveChatEventID(_ eventID: UUID?) {
        activeChatEventID = eventID
    }

    static func setUserSignedIn(_ isSignedIn: Bool) {
        isUserSignedIn = isSignedIn
    }

    // When the main tab view appears and the app is signed in, consume any pending notification open context and return it to the app for handling.
    static func consumePendingOpenedNotificationContext() -> OpenedNotificationContext? {
        defer {
            pendingOpenedNotificationContext = nil
        }

        return pendingOpenedNotificationContext
    }

    static func requestRemoteNotificationRegistration() {
        print("NotificationService: requesting remote notification registration. hasCurrentToken=\(currentDeviceToken != nil).")

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { isGranted, error in
            if let error {
                print("NotificationService: notification permission request failed: \(error.localizedDescription)")
            }

            print("NotificationService: notification permission granted: \(isGranted)")

            // Register with APNs even when alert permission is denied, so the app can still receive a device token.
            DispatchQueue.main.async {
                print("NotificationService: calling registerForRemoteNotifications.")
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    static func unregisterRemoteNotifications() {
        currentDeviceToken = nil
        activeChatEventID = nil

        DispatchQueue.main.async {
            UIApplication.shared.unregisterForRemoteNotifications()
        }
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Self.requestRemoteNotificationRegistration()
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
        print("NotificationService: registered APNs device token. tokenSuffix=\(token.suffix(8)).")

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
        completionHandler(.newData)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        print("NotificationService: received foreground notification.")

        guard Self.isUserSignedIn else {
            print("NotificationService: suppressed notification while signed out.")
            return []
        }

        if shouldSuppressChatNotification(notification) {
            print("NotificationService: suppressed notification for active chat room.")
            return []
        }

        return [.banner, .badge, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        print("NotificationService: user opened notification.")
        postRemoteNotificationDidOpen(response.notification.request.content.userInfo)
    }

    private func postRemoteNotificationDidOpen(_ userInfo: [AnyHashable: Any]) {
        if !Self.isUserSignedIn {
            print("NotificationService: stored notification open while signed out.")
        }

        let notificationID = (userInfo["notification_id"] as? String).flatMap(UUID.init(uuidString:))
        let rawNotificationType = userInfo["notification_type"] as? String
        let notificationType = rawNotificationType.flatMap(NotificationType.init(rawValue:))
        let relatedEventID = (userInfo["related_event_id"] as? String).flatMap(UUID.init(uuidString:))

        // Store the tapped notification payload so it can be consumed by the app when the app process is restored
        let context = OpenedNotificationContext(
            notificationID: notificationID,
            notificationType: notificationType,
            rawNotificationType: rawNotificationType,
            relatedEventID: relatedEventID
        )
        Self.pendingOpenedNotificationContext = context

        NotificationCenter.default.post(
            name: Self.remoteNotificationDidOpenNotification,
            object: context
        )
    }

    private func shouldSuppressChatNotification(_ notification: UNNotification) -> Bool {
        let userInfo = notification.request.content.userInfo

        guard userInfo["notification_type"] as? String == Constants.Chat.messageNotificationType,
              let eventIDString = userInfo["related_event_id"] as? String,
              let eventID = UUID(uuidString: eventIDString) else {
            return false
        }

        return eventID == Self.activeChatEventID
    }
}
