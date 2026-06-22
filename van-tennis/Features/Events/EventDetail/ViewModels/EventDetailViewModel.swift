import Combine
import Foundation

@MainActor
final class EventDetailViewModel: ObservableObject {
    @Published var hostProfile: UserProfile?
    @Published var participantProfiles: [UserProfile] = []
    @Published var isLoading = false
    @Published var isJoining = false
    @Published var isLeaving = false
    @Published var isUpdatingMaxPlayers = false
    @Published var isSubmittingReport = false
    @Published var errorMessage: String?

    private let profileService = ProfileService()
    private let eventService = EventService()
    private let notificationEventService = NotificationEventService()
    private let reportService = ReportService()

    func loadDetails(for event: TennisEvent) async -> TennisEvent? {
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
        }

        do {
            guard let latestEvent = try await eventService.fetchEventDetails(id: event.id) else {
                throw EventDetailViewModelError.eventNotFound
            }

            hostProfile = try await profileService.findProfile(userID: latestEvent.hostID)

            participantProfiles = try await profileService
                .fetchProfiles(userIDs: latestEvent.participants)
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

            return latestEvent
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func hasRequestedToJoin(event: TennisEvent, currentUserID: UUID?) async -> Bool {
        guard let currentUserID else {
            return false
        }

        do {
            return try await notificationEventService.hasJoinRequest(
                senderID: currentUserID,
                hostID: event.hostID,
                eventID: event.id
            )
        } catch {
            print("EventDetailViewModel: failed to check join request: \(error.localizedDescription)")
            return false
        }
    }

    func joinEvent(_ event: TennisEvent, currentUser: UserProfile) async throws {
        guard let latestEvent = try await eventService.fetchEventDetails(id: event.id) else {
            throw EventDetailViewModelError.eventNotFound
        }

        guard !latestEvent.participants.contains(currentUser.id) else {
            return
        }

        if latestEvent.isFull {
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
                recipients: [latestEvent.hostID],
                notificationType: .eventJoined,
                title: "Player wants to join your event",
                body: "\(currentUser.displayName) wants to join your event at \(latestEvent.court.displayName).",
                relatedEventID: latestEvent.id
            )
        )
    }

    func leaveEvent(_ event: TennisEvent, currentUser: UserProfile) async throws {
        guard let latestEvent = try await eventService.fetchEventDetails(id: event.id) else {
            throw EventDetailViewModelError.eventNotFound
        }

        guard latestEvent.participants.contains(currentUser.id) else {
            return
        }

        isLeaving = true
        errorMessage = nil
        defer {
            isLeaving = false
        }

        try await eventService.leaveEvent(eventID: latestEvent.id)

        _ = try await notificationEventService.createNotification(
            NewNotificationEvent(
                sender: currentUser.id,
                recipients: [latestEvent.hostID],
                notificationType: .eventLeft,
                title: "Player left your event",
                body: "\(currentUser.displayName) left your event at \(latestEvent.court.displayName).",
                relatedEventID: latestEvent.id
            )
        )
    }

    func updateMaxPlayers(_ maxPlayers: Int?, for event: TennisEvent) async throws -> TennisEvent {
        if let maxPlayers, maxPlayers < event.playerCount {
            throw EventDetailViewModelError.maxPlayersBelowCurrentPlayerCount(event.playerCount)
        }

        isUpdatingMaxPlayers = true
        errorMessage = nil
        defer {
            isUpdatingMaxPlayers = false
        }

        return try await eventService.updateMaxPlayers(
            eventID: event.id,
            maxPlayers: maxPlayers
        )
    }

    func submitReport(
        event: TennisEvent,
        reporter: UserProfile,
        reportedUserIDs: [UUID],
        reason: ReportReason,
        details: String
    ) async throws {
        guard !reportedUserIDs.isEmpty else {
            return
        }

        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let reports = reportedUserIDs.map {
            NewReport(
                reporterID: reporter.id,
                reportedUserID: $0,
                reportedEventID: event.id,
                reason: reason,
                details: trimmedDetails.isEmpty ? nil : trimmedDetails
            )
        }

        isSubmittingReport = true
        errorMessage = nil
        defer {
            isSubmittingReport = false
        }

        _ = try await reportService.createReports(reports)
    }
}

enum EventDetailViewModelError: LocalizedError {
    case eventNotFound
    case eventIsFull
    case maxPlayersBelowCurrentPlayerCount(Int)

    var errorDescription: String? {
        switch self {
        case .eventNotFound:
            return "This event is no longer available."
        case .eventIsFull:
            return "This event is already full."
        case .maxPlayersBelowCurrentPlayerCount(let playerCount):
            return "Maximum players cannot be less than the current player count of \(playerCount)."
        }
    }
}
