import Combine
import Foundation

@MainActor
final class MyEventsViewModel: ObservableObject {
    @Published var events: [TennisEvent] = []
    @Published var currentUserProfile: UserProfile?
    @Published var hostProfilesByID: [UUID: UserProfile] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let eventService = EventService()
    private let profileService = ProfileService()
    private var refreshTask: Task<Void, Never>?

    func refreshEvents(appState: AppState, showsLoading: Bool = false) {
        refreshEvents(
            currentUserID: appState.userProfile?.id,
            showsLoading: showsLoading
        ) { eventIDs in
            if let eventIDs {
                appState.updateCachedEvents(
                    hostedEvents: eventIDs.hostedEvents,
                    participatedEvents: eventIDs.participatedEvents
                )
                appState.updateCachedAllEventsRead(true)
            }
        }
    }

    func refreshEvents(
        currentUserID: UUID?,
        showsLoading: Bool = false,
        onComplete: (@MainActor (MyEventsProfileEventIDs?) async -> Void)? = nil
    ) {
        guard refreshTask == nil else {
            return
        }

        refreshTask = Task { [weak self] in
            let eventIDs = await self?.loadEvents(
                currentUserID: currentUserID,
                showsLoading: showsLoading
            )
            await onComplete?(eventIDs)
            await MainActor.run {
                self?.refreshTask = nil
            }
        }
    }

    func loadEvents(appState: AppState, showsLoading: Bool = false) async {
        if let eventIDs = await loadEvents(
            currentUserID: appState.userProfile?.id,
            showsLoading: showsLoading
        ) {
            appState.updateCachedEvents(
                hostedEvents: eventIDs.hostedEvents,
                participatedEvents: eventIDs.participatedEvents
            )
            appState.updateCachedAllEventsRead(true)
        }
    }

    func loadEvents(currentUserID: UUID?, showsLoading: Bool = false) async -> MyEventsProfileEventIDs? {
        guard !isLoading else {
            return nil
        }

        guard let currentUserID else {
            events = []
            errorMessage = AppContent.string("errors.noAuthenticatedUser")
            return MyEventsProfileEventIDs(hostedEvents: [], participatedEvents: [])
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
                events = []
                currentUserProfile = nil
                errorMessage = AppContent.string("errors.userProfileNotFound")
                return MyEventsProfileEventIDs(hostedEvents: [], participatedEvents: [])
            }

            currentUserProfile = profile
            hostProfilesByID[profile.id] = profile

            let eventIDs = Array(Set(profile.hostedEvents + profile.participatedEvents))
            let now = Date()
            events = try await eventService.fetchEvents(ids: eventIDs)
                .filter { $0.endTime > now }

            await loadMissingHostProfiles(for: events, currentUserID: currentUserID)
            _ = try await profileService.updateProfile(
                userID: currentUserID,
                isAllEventsRead: true
            )

            return MyEventsProfileEventIDs(
                hostedEvents: events
                    .filter { $0.hostID == currentUserID }
                    .map(\.id),
                participatedEvents: events
                    .filter { $0.participants.contains(currentUserID) }
                    .map(\.id)
            )
        } catch is CancellationError {
            print("MyEventsViewModel: events load was cancelled.")
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func removeEvent(id: UUID) {
        events.removeAll { $0.id == id }
    }

    func isHostedByCurrentUser(_ event: TennisEvent, currentUserID: UUID?) -> Bool {
        event.hostID == currentUserID
    }

    func hostDisplayNameOverride(for event: TennisEvent, currentUserID: UUID?) -> String? {
        isHostedByCurrentUser(event, currentUserID: currentUserID) ? AppContent.string("events.card.hostYou") : nil
    }

    func hostProfile(for event: TennisEvent, currentUserProfile fallbackProfile: UserProfile?) -> UserProfile? {
        if event.hostID == fallbackProfile?.id {
            return currentUserProfile ?? fallbackProfile
        }

        return hostProfilesByID[event.hostID]
    }

    private func loadMissingHostProfiles(for events: [TennisEvent], currentUserID: UUID) async {
        let missingHostIDs = Array(
            Set(events.map(\.hostID))
                .filter { $0 != currentUserID }
                .filter { hostProfilesByID[$0] == nil }
        )

        guard !missingHostIDs.isEmpty else {
            return
        }

        do {
            let hostProfiles = try await profileService.fetchProfiles(userIDs: missingHostIDs)

            for profile in hostProfiles {
                hostProfilesByID[profile.id] = profile
            }
        } catch {
            print("MyEventsViewModel: failed to load host profiles: \(error.localizedDescription)")
        }
    }
}

struct MyEventsProfileEventIDs {
    let hostedEvents: [UUID]
    let participatedEvents: [UUID]
}
