import Combine
import Foundation

@MainActor
final class MyEventsViewModel: ObservableObject {
    @Published var events: [TennisEvent] = []
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
                errorMessage = AppContent.string("errors.userProfileNotFound")
                return MyEventsProfileEventIDs(hostedEvents: [], participatedEvents: [])
            }

            let eventIDs = Array(Set(profile.hostedEvents + profile.participatedEvents))
            let now = Date()
            events = try await eventService.fetchEvents(ids: eventIDs)
                .filter { $0.endTime > now }

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

}

struct MyEventsProfileEventIDs {
    let hostedEvents: [UUID]
    let participatedEvents: [UUID]
}
