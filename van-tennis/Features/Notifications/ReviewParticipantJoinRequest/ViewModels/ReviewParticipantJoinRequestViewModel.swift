import Combine
import Foundation

@MainActor
final class ReviewParticipantJoinRequestViewModel: ObservableObject {
    @Published var senderProfile: UserProfile?
    @Published var isLoading = false
    @Published var isApproving = false
    @Published var isDisapproving = false
    @Published var hasCompletedReview = false
    @Published var errorMessage: String?

    private let profileService = ProfileService()
    private let notificationEventService = NotificationEventService()

    func loadSenderProfile(senderID: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            senderProfile = try await profileService.findProfile(userID: senderID)

            if senderProfile == nil {
                errorMessage = "Player profile was not found."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func approveJoinRequest(notification: NotificationEvent, currentUser: UserProfile?) async -> Bool {
        guard let currentUser else {
            errorMessage = "No authenticated user was found."
            return false
        }

        guard let relatedEventID = notification.relatedEventID else {
            errorMessage = "This join request is missing an event."
            return false
        }

        isApproving = true
        errorMessage = nil
        defer {
            isApproving = false
        }

        do {
            try await notificationEventService.approveJoinRequest(notificationID: notification.id)

            _ = try await notificationEventService.createNotification(
                NewNotificationEvent(
                    sender: currentUser.id,
                    recipients: [notification.sender],
                    notificationType: .approveJoinRequest,
                    title: "Join request approved",
                    body: "\(currentUser.displayName) approved your request to join the event.",
                    relatedEventID: relatedEventID
                )
            )

            try await notificationEventService.deleteNotificationForCurrentUser(
                notificationID: notification.id
            )

            hasCompletedReview = true
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func rejectJoinRequest(notification: NotificationEvent, currentUser: UserProfile?) async -> Bool {
        guard let currentUser else {
            errorMessage = "No authenticated user was found."
            return false
        }

        guard let relatedEventID = notification.relatedEventID else {
            errorMessage = "This join request is missing an event."
            return false
        }

        isDisapproving = true
        errorMessage = nil
        defer {
            isDisapproving = false
        }

        do {
            _ = try await notificationEventService.createNotification(
                NewNotificationEvent(
                    sender: currentUser.id,
                    recipients: [notification.sender],
                    notificationType: .rejectJoinRequest,
                    title: "Join request declined",
                    body: "\(currentUser.displayName) declined your request to join the event.",
                    relatedEventID: relatedEventID
                )
            )

            try await notificationEventService.deleteNotificationForCurrentUser(
                notificationID: notification.id
            )

            hasCompletedReview = true
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
