import Combine
import Foundation

@MainActor
final class MyEventsViewModel: ObservableObject {
    @Published var events: [TennisEvent] = []
    @Published var archivingEventIDs: Set<UUID> = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let eventService = EventService()
    private let profileService = ProfileService()
    private var refreshTask: Task<Void, Never>?

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

    func loadEvents(currentUserID: UUID?, showsLoading: Bool = false) async -> MyEventsProfileEventIDs? {
        guard !isLoading else {
            return nil
        }

        guard let currentUserID else {
            events = []
            errorMessage = "No authenticated user was found."
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
                errorMessage = "User profile was not found."
                return MyEventsProfileEventIDs(hostedEvents: [], participatedEvents: [])
            }

            let eventIDs = Array(Set(profile.hostedEvents + profile.participatedEvents))
            events = try await eventService.fetchEvents(ids: eventIDs)
            return MyEventsProfileEventIDs(
                hostedEvents: profile.hostedEvents,
                participatedEvents: profile.participatedEvents
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

    func archiveEndedEvent(_ event: TennisEvent) async -> Bool {
        guard event.endTime <= Date() else {
            errorMessage = "Only ended events can be archived."
            return false
        }

        guard !archivingEventIDs.contains(event.id) else {
            return false
        }

        archivingEventIDs.insert(event.id)
        errorMessage = nil
        defer {
            archivingEventIDs.remove(event.id)
        }

        do {
            try await eventService.archiveEndedEvent(eventID: event.id)
            removeEvent(id: event.id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

struct MyEventsProfileEventIDs {
    let hostedEvents: [UUID]
    let participatedEvents: [UUID]
}
