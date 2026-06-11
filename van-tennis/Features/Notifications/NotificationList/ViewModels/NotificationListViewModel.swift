import Combine
import Foundation

@MainActor
final class NotificationListViewModel: ObservableObject {
    @Published var notifications: [NotificationEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let profileService = ProfileService()
    private let notificationEventService = NotificationEventService()

    func loadNotifications(currentUserID: UUID?) async {
        guard let currentUserID else {
            notifications = []
            errorMessage = "No authenticated user was found."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            guard let profile = try await profileService.findProfile(userID: currentUserID) else {
                notifications = []
                errorMessage = "User profile was not found."
                isLoading = false
                return
            }

            notifications = try await notificationEventService.fetchNotifications(
                ids: profile.notifications
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
