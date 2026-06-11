import Combine
import Foundation

@MainActor
final class NotificationListViewModel: ObservableObject {
    @Published var notifications: [NotificationEvent] = []
    @Published var deletingNotificationIDs: Set<UUID> = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let profileService = ProfileService()
    private let notificationEventService = NotificationEventService()
    private var refreshTask: Task<Void, Never>?

    func refreshNotifications(currentUserID: UUID?, showsLoading: Bool = false) {
        guard refreshTask == nil else {
            return
        }

        refreshTask = Task { [weak self] in
            await self?.loadNotifications(
                currentUserID: currentUserID,
                showsLoading: showsLoading
            )
            await MainActor.run {
                self?.refreshTask = nil
            }
        }
    }

    func loadNotifications(currentUserID: UUID?, showsLoading: Bool = false) async {
        guard !isLoading else {
            return
        }

        guard let currentUserID else {
            notifications = []
            errorMessage = "No authenticated user was found."
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
                errorMessage = "User profile was not found."
                return
            }

            notifications = try await notificationEventService.fetchNotifications(
                ids: profile.notifications
            )
            print("NotificationListViewModel: loaded \(notifications.count) notifications.")
        } catch is CancellationError {
            print("NotificationListViewModel: notification load was cancelled.")
            return
        } catch {
            print("NotificationListViewModel: failed to load notifications: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func deleteNotification(_ notification: NotificationEvent, currentUserID: UUID?) async {
        guard currentUserID != nil else {
            errorMessage = "No authenticated user was found."
            return
        }

        guard !deletingNotificationIDs.contains(notification.id) else {
            return
        }

        deletingNotificationIDs.insert(notification.id)
        errorMessage = nil

        do {
            try await notificationEventService.deleteNotificationForCurrentUser(
                notificationID: notification.id
            )
            notifications.removeAll { $0.id == notification.id }
        } catch {
            errorMessage = error.localizedDescription
        }

        deletingNotificationIDs.remove(notification.id)
    }
}
