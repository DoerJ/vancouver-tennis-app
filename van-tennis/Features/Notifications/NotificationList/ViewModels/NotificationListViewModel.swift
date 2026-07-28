import Combine
import Foundation

@MainActor
final class NotificationListViewModel: ObservableObject {
    @Published var notifications: [NotificationEvent] = []
    @Published var deletingNotificationIDs: Set<UUID> = []
    @Published var markingReadNotificationIDs: Set<UUID> = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let profileService = ProfileService()
    private let notificationEventService = NotificationEventService()
    private var refreshTask: Task<Void, Never>?

    func refreshNotifications(appState: AppState, showsLoading: Bool = false) {
        guard refreshTask == nil else {
            return
        }

        refreshTask = Task { [weak self] in
            await self?.loadNotifications(appState: appState, showsLoading: showsLoading)
            await MainActor.run {
                self?.refreshTask = nil
            }
        }
    }

    func loadNotifications(appState: AppState, showsLoading: Bool = false) async {
        guard !isLoading else {
            return
        }

        let currentUserID = appState.userProfile?.id

        guard let currentUserID else {
            notifications = []
            errorMessage = AppContent.string("errors.noAuthenticatedUser")
            return
        }

        if showsLoading {
            isLoading = true
        }

        errorMessage = nil
        defer {
            if showsLoading {
                isLoading = false
            }
        }

        do {
            guard let profile = try await profileService.findProfile(userID: currentUserID) else {
                notifications = []
                errorMessage = AppContent.string("errors.userProfileNotFound")
                return
            }

            appState.updateCachedNotifications(profile.notifications)

            notifications = try await notificationEventService.fetchNotifications(
                ids: appState.cachedNotifications.map(\.id)
            )
            appState.updateCachedNotifications(notifications, currentUserID: currentUserID)

            if profile.isAllNotificationsRead == false {
                _ = try await profileService.updateProfile(
                    userID: currentUserID,
                    isAllNotificationsRead: true
                )
                appState.updateCachedAllNotificationsRead(true)
            }

        } catch is CancellationError {
            print("NotificationListViewModel: notification load was cancelled.")
        } catch {
            print("NotificationListViewModel: failed to load notifications: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    // Fetch a single notification by ID, to handle user click event on a join request foreground notification
    func notification(id notificationID: UUID) async -> NotificationEvent? {
        if let notification = notifications.first(where: { $0.id == notificationID }) {
            return notification
        }

        do {
            return try await notificationEventService.fetchNotification(id: notificationID)
        } catch {
            print("NotificationListViewModel: failed to fetch notification \(notificationID): \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func deleteNotification(_ notification: NotificationEvent, currentUserID: UUID?) async -> Bool {
        guard currentUserID != nil else {
            errorMessage = AppContent.string("errors.noAuthenticatedUser")
            return false
        }

        guard !deletingNotificationIDs.contains(notification.id) else {
            return false
        }

        deletingNotificationIDs.insert(notification.id)
        errorMessage = nil

        do {
            try await notificationEventService.deleteNotificationForCurrentUser(
                notificationID: notification.id
            )
            notifications.removeAll { $0.id == notification.id }
            deletingNotificationIDs.remove(notification.id)
            return true
        } catch {
            errorMessage = error.localizedDescription
        }

        deletingNotificationIDs.remove(notification.id)
        return false
    }

    func markNotificationRead(_ notification: NotificationEvent, currentUserID: UUID?) async -> Bool {
        guard let currentUserID else {
            errorMessage = AppContent.string("errors.noAuthenticatedUser")
            return false
        }

        guard !notification.isRead(by: currentUserID),
              !markingReadNotificationIDs.contains(notification.id) else {
            return false
        }

        markingReadNotificationIDs.insert(notification.id)
        errorMessage = nil
        defer {
            markingReadNotificationIDs.remove(notification.id)
        }

        do {
            try await notificationEventService.markNotificationRead(notificationID: notification.id)
            return true
        } catch is CancellationError {
            print("NotificationListViewModel: mark notification read was cancelled.")
        } catch {
            errorMessage = error.localizedDescription
        }

        return false
    }
}
