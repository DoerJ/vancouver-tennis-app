import Combine
import Foundation

@MainActor
final class ChatListViewModel: ObservableObject {
    @Published private(set) var events: [TennisEvent] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let eventService = EventService()

    func loadEvents(appState: AppState) async {
        guard let profile = appState.userProfile else {
            events = []
            isLoading = false
            errorMessage = nil
            return
        }

        let eventIDs = Array(Set(profile.hostedEvents + profile.participatedEvents))
        guard !eventIDs.isEmpty else {
            events = []
            isLoading = false
            errorMessage = nil
            return
        }

        isLoading = events.isEmpty
        errorMessage = nil
        defer {
            isLoading = false
        }

        do {
            updateEventsFromCache(eventIDs: eventIDs, appState: appState)

            let missingEventIDs = appState.missingCachedEventIDs(ids: eventIDs)
            if !missingEventIDs.isEmpty {
                let fetchedEvents = try await eventService.fetchEvents(ids: missingEventIDs)
                appState.updateCachedEvents(fetchedEvents)
                updateEventsFromCache(eventIDs: eventIDs, appState: appState)
            }

            let uncachedMessageEventIDs = events
                .map(\.id)
                .filter { appState.cachedChatMessages(eventID: $0) == nil }

            if !uncachedMessageEventIDs.isEmpty {
                await appState.preloadCachedChatMessages(eventIDs: uncachedMessageEventIDs)
            }
        } catch is CancellationError {
            // Expected if the view disappears while the list is loading.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateEventsFromCache(eventIDs: [UUID], appState: AppState) {
        events = appState.cachedEvents(ids: eventIDs)
            .filter { $0.endTime > Date() }
            .sorted { $0.startTime < $1.startTime }
    }
}
