import Combine
import Foundation

@MainActor
final class ReviewParticipantJoinRequestViewModel: ObservableObject {
    @Published var senderProfile: UserProfile?
    @Published var relatedEvent: TennisEvent?
    @Published var isLoading = false
    @Published var isApproving = false
    @Published var isDisapproving = false
    @Published var hasCompletedReview = false
    @Published var errorMessage: String?

    private let profileService = ProfileService()
    private let eventService = EventService()
    private let notificationEventService = NotificationEventService()

    func loadReviewDetails(notification: NotificationEvent) async {
        isLoading = true
        errorMessage = nil

        do {
            if let senderID = notification.sender {
                senderProfile = try await profileService.findProfile(userID: senderID)

                if senderProfile == nil {
                    errorMessage = "Player profile was not found."
                }
            }

            if let relatedEventID = notification.relatedEventID {
                relatedEvent = try await eventService.fetchEventDetails(id: relatedEventID)
            }

            if let reviewUnavailableMessage {
                errorMessage = reviewUnavailableMessage
            }

            if notification.sender == nil {
                errorMessage = "Player profile was not found."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func approveJoinRequest(notification: NotificationEvent, currentUser: UserProfile?) async -> Bool {
        guard canReviewJoinRequest else {
            errorMessage = reviewUnavailableMessage
            return false
        }

        guard let currentUser else {
            errorMessage = "No authenticated user was found."
            return false
        }

        guard let relatedEventID = notification.relatedEventID else {
            errorMessage = "This join request is missing an event."
            return false
        }

        guard let requesterID = notification.sender else {
            errorMessage = "This join request is missing a player."
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
                    recipients: [requesterID],
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
        guard canReviewJoinRequest else {
            errorMessage = reviewUnavailableMessage
            return false
        }

        guard let currentUser else {
            errorMessage = "No authenticated user was found."
            return false
        }

        guard let relatedEventID = notification.relatedEventID else {
            errorMessage = "This join request is missing an event."
            return false
        }

        guard let requesterID = notification.sender else {
            errorMessage = "This join request is missing a player."
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
                    recipients: [requesterID],
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

    var canReviewJoinRequest: Bool {
        guard let relatedEvent else {
            return false
        }

        return relatedEvent.endTime > Date()
    }

    private var reviewUnavailableMessage: String? {
        guard let relatedEvent else {
            return "This event is no longer available."
        }

        guard relatedEvent.endTime > Date() else {
            return "This event has already ended. Join requests can no longer be reviewed."
        }

        return nil
    }
}
