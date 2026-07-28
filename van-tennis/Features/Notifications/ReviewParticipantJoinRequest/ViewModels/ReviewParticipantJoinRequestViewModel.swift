import Combine
import Foundation

@MainActor
final class ReviewParticipantJoinRequestViewModel: ObservableObject {
    @Published var senderProfile: UserProfile?
    @Published var relatedEvent: TennisEvent?
    @Published var isLoading = false
    @Published var isApproving = false
    @Published var isDisapproving = false
    @Published var isDeleting = false
    @Published var hasCompletedReview = false
    @Published var errorMessage: String?
    @Published var requestCancelledMessage: String?

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
                    errorMessage = AppContent.string("joinRequest.profileNotFound")
                }
            }

            if let relatedEventID = notification.relatedEventID {
                relatedEvent = try await eventService.fetchEventDetails(id: relatedEventID)
            }

            if let reviewUnavailableMessage {
                errorMessage = reviewUnavailableMessage
            }

            if notification.sender == nil {
                errorMessage = AppContent.string("joinRequest.profileNotFound")
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
            errorMessage = AppContent.string("errors.noAuthenticatedUser")
            return false
        }

        guard let relatedEventID = notification.relatedEventID else {
            errorMessage = AppContent.string("joinRequest.missingEvent")
            return false
        }

        guard let requesterID = notification.sender else {
            errorMessage = AppContent.string("joinRequest.missingPlayer")
            return false
        }

        isApproving = true
        errorMessage = nil
        defer {
            isApproving = false
        }

        do {
            guard try await isRequesterStillPending(requesterID: requesterID, eventID: relatedEventID) else {
                requestCancelledMessage = AppContent.string("joinRequest.requestCancelled")
                return false
            }

            try await notificationEventService.approveJoinRequest(notificationID: notification.id)

            _ = try await notificationEventService.createNotification(
                NewNotificationEvent(
                    sender: currentUser.id,
                    recipients: [requesterID],
                    notificationType: .approveJoinRequest,
                    title: AppContent.string("joinRequest.approvedTitle"),
                    body: AppContent.string("joinRequest.approvedBody", currentUser.displayName),
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
            errorMessage = AppContent.string("errors.noAuthenticatedUser")
            return false
        }

        guard let relatedEventID = notification.relatedEventID else {
            errorMessage = AppContent.string("joinRequest.missingEvent")
            return false
        }

        guard let requesterID = notification.sender else {
            errorMessage = AppContent.string("joinRequest.missingPlayer")
            return false
        }

        isDisapproving = true
        errorMessage = nil
        defer {
            isDisapproving = false
        }

        do {
            guard try await isRequesterStillPending(requesterID: requesterID, eventID: relatedEventID) else {
                requestCancelledMessage = AppContent.string("joinRequest.requestCancelled")
                return false
            }

            _ = try await notificationEventService.createNotification(
                NewNotificationEvent(
                    sender: currentUser.id,
                    recipients: [requesterID],
                    notificationType: .rejectJoinRequest,
                    title: AppContent.string("joinRequest.declinedTitle"),
                    body: AppContent.string("joinRequest.declinedBody", currentUser.displayName),
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

    func deleteJoinRequestNotification(notification: NotificationEvent, currentUser: UserProfile?) async -> Bool {
        guard currentUser != nil else {
            errorMessage = AppContent.string("errors.noAuthenticatedUser")
            return false
        }

        isDeleting = true
        errorMessage = nil
        defer {
            isDeleting = false
        }

        do {
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

    private func isRequesterStillPending(requesterID: UUID, eventID: UUID) async throws -> Bool {
        let pendingParticipants = try await eventService.fetchPendingParticipants(eventID: eventID)
        return pendingParticipants.contains(requesterID)
    }

    private var reviewUnavailableMessage: String? {
        guard let relatedEvent else {
            return AppContent.string("joinRequest.eventUnavailable")
        }

        guard relatedEvent.endTime > Date() else {
            return AppContent.string("joinRequest.eventEnded")
        }

        return nil
    }
}
