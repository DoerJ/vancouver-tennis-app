import Combine
import Foundation

@MainActor
final class EventDetailViewModel: ObservableObject {
    @Published var hostProfile: UserProfile?
    @Published var participantProfiles: [UserProfile] = []
    @Published var isLoading = false
    @Published var isJoining = false
    @Published var errorMessage: String?

    private let profileService = ProfileService()
    private let notificationEventService = NotificationEventService()

    func loadDetails(for event: TennisEvent) async {
        isLoading = true
        errorMessage = nil

        do {
            hostProfile = try await profileService.findProfile(userID: event.hostID)

            participantProfiles = try await profileService
                .fetchProfiles(userIDs: event.participants)
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func joinEvent(_ event: TennisEvent, currentUser: UserProfile) async throws {
        guard event.hostID != currentUser.id else {
            throw EventDetailViewModelError.hostCannotJoinOwnEvent
        }

        guard !event.participants.contains(currentUser.id) else {
            return
        }

        if let maxPlayers = event.maxPlayers, event.participants.count >= maxPlayers {
            throw EventDetailViewModelError.eventIsFull
        }

        isJoining = true
        errorMessage = nil
        defer {
            isJoining = false
        }

        _ = try await notificationEventService.createNotification(
            NewNotificationEvent(
                sender: currentUser.id,
                recipients: [event.hostID],
                notificationType: .eventJoined,
                title: "Player wants to join your event",
                body: "\(currentUser.displayName) wants to join your event at \(event.court.displayName).",
                relatedEventID: event.id
            )
        )
    }
}

enum EventDetailViewModelError: LocalizedError {
    case hostCannotJoinOwnEvent
    case eventIsFull

    var errorDescription: String? {
        switch self {
        case .hostCannotJoinOwnEvent:
            return "Hosts cannot join their own event."
        case .eventIsFull:
            return "This event is already full."
        }
    }
}
