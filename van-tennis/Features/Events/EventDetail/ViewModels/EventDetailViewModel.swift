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
        } catch is CancellationError {
            print("EventDetailViewModel: event details load was cancelled.")
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func requestToJoinEvent(_ event: TennisEvent, appState: AppState) async -> Bool {
        guard let currentUser = appState.userProfile else {
            errorMessage = AppContent.string("errors.noAuthenticatedUser")
            return false
        }

        do {
            try await joinEvent(event, currentUser: currentUser, appState: appState)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func joinEvent(_ event: TennisEvent, currentUser: UserProfile, appState: AppState) async throws {
        guard let latestEvent = try await eventService.fetchEventDetails(id: event.id) else {
            throw EventDetailViewModelError.eventNotFound
        }

        guard !latestEvent.participants.contains(currentUser.id) else {
            return
        }

        if latestEvent.isFull {
            throw EventDetailViewModelError.eventIsFull
        }

        let activeEvents = try await appState.activeEventsForCurrentUser()
        if activeEvents.contains(where: { existingEvent in
            existingEvent.id != latestEvent.id
                && EventOverlapHelper.overlaps(
                    startTime: latestEvent.startTime,
                    endTime: latestEvent.endTime,
                    existingEvent: existingEvent
                )
        }) {
            throw EventDetailViewModelError.eventOverlapsExistingEvent
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
                title: AppContent.string("events.notifications.joinRequestTitle"),
                body: AppContent.string(
                    "events.notifications.joinRequestBody",
                    currentUser.displayName,
                    latestEvent.court.displayName
                ),
                relatedEventID: latestEvent.id
            )
        )
        appState.appendCachedPendingEvent(latestEvent.id)
    }

    func leaveEvent(_ event: TennisEvent, appState: AppState) async -> Bool {
        guard let currentUser = appState.userProfile else {
            errorMessage = AppContent.string("errors.noAuthenticatedUser")
            return false
        }

        do {
            try await leaveEvent(event, currentUser: currentUser)
            appState.removeCachedEvent(event.id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func leaveEvent(_ event: TennisEvent, currentUser: UserProfile) async throws {
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

        let recipients = Array(
            Set([latestEvent.hostID] + latestEvent.participants)
                .subtracting([currentUser.id])
        )

        if !recipients.isEmpty {
            _ = try await notificationEventService.createNotification(
                NewNotificationEvent(
                    sender: currentUser.id,
                    recipients: recipients,
                    notificationType: .eventLeft,
                    title: AppContent.string("events.notifications.leftTitle"),
                    body: AppContent.string(
                        "events.notifications.leftBody",
                        currentUser.displayName,
                        latestEvent.court.displayName
                    ),
                    relatedEventID: latestEvent.id
                )
            )
        }
    }

    func cancelHostedEvent(_ event: TennisEvent, appState: AppState) async -> Bool {
        errorMessage = nil

        do {
            try await appState.cancelHostedEvent(event)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func updateMaxPlayers(_ maxPlayers: Int?, for event: TennisEvent) async throws -> TennisEvent {
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

    func saveMaxPlayersUpdate(_ pendingMaxPlayers: Int?, for event: TennisEvent) async throws -> TennisEvent? {
        guard let pendingMaxPlayers else {
            return nil
        }

        let hasMaxPlayersChange = event.maxPlayers.map { $0 != pendingMaxPlayers } ?? true
        guard hasMaxPlayersChange else {
            return nil
        }

        return try await updateMaxPlayers(pendingMaxPlayers, for: event)
    }

    private func submitReport(
        event: TennisEvent,
        reporter: UserProfile,
        reportedUserIDs: [UUID],
        reasons: [ReportReason],
        details: String
    ) async throws {
        guard !reportedUserIDs.isEmpty, !reasons.isEmpty else {
            return
        }

        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let reports = reportedUserIDs.flatMap { reportedUserID in
            reasons.map { reason in
                NewReport(
                    reporterID: reporter.id,
                    reportedUserID: reportedUserID,
                    reportedEventID: event.id,
                    reason: reason,
                    details: trimmedDetails.isEmpty ? nil : trimmedDetails
                )
            }
        }

        isSubmittingReport = true
        errorMessage = nil
        defer {
            isSubmittingReport = false
        }

        _ = try await reportService.createReports(reports)
    }

    func submitReport(
        event: TennisEvent,
        appState: AppState,
        reportedUserIDs: [UUID],
        reasons: [ReportReason],
        details: String
    ) async -> Bool {
        guard let currentUser = appState.userProfile else {
            errorMessage = AppContent.string("errors.noAuthenticatedUser")
            return false
        }

        do {
            try await submitReport(
                event: event,
                reporter: currentUser,
                reportedUserIDs: reportedUserIDs,
                reasons: reasons,
                details: details
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

enum EventDetailViewModelError: LocalizedError {
    case eventNotFound
    case eventIsFull
    case maxPlayersBelowCurrentPlayerCount(Int)
    case eventOverlapsExistingEvent

    var errorDescription: String? {
        switch self {
        case .eventNotFound:
            return AppContent.string("errors.eventNotFound")
        case .eventIsFull:
            return AppContent.string("errors.eventFull")
        case .maxPlayersBelowCurrentPlayerCount(let playerCount):
            return AppContent.string("events.errors.maxPlayersBelowCurrentCount", playerCount)
        case .eventOverlapsExistingEvent:
            return AppContent.string("events.detail.overlap")
        }
    }
}
