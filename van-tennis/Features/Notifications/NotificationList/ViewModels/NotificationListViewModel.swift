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

    func refreshNotifications(
        currentUserID: UUID?,
        showsLoading: Bool = false,
        onComplete: (@MainActor ([UUID]?) async -> Void)? = nil
    ) {
        guard refreshTask == nil else {
            return
        }

        refreshTask = Task { [weak self] in
            let notificationIDs = await self?.loadNotifications(
                currentUserID: currentUserID,
                showsLoading: showsLoading
            )
            await onComplete?(notificationIDs)
            await MainActor.run {
                self?.refreshTask = nil
            }
        }
    }

    func loadNotifications(currentUserID: UUID?, showsLoading: Bool = false) async -> [UUID]? {
        guard !isLoading else {
            return nil
        }

        guard let currentUserID else {
            notifications = []
            errorMessage = AppContent.string("errors.noAuthenticatedUser")
            return []
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
                return []
            }

            notifications = try await notificationEventService.fetchNotifications(
                ids: profile.notifications
            )
            print("NotificationListViewModel: loaded \(notifications.count) notifications.")
            return profile.notifications
        } catch is CancellationError {
            print("NotificationListViewModel: notification load was cancelled.")
            return nil
        } catch {
            print("NotificationListViewModel: failed to load notifications: \(error.localizedDescription)")
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
}
