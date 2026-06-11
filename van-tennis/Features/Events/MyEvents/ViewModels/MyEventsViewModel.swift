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

    func refreshEvents(currentUserID: UUID?, showsLoading: Bool = false) {
        guard refreshTask == nil else {
            return
        }

        refreshTask = Task { [weak self] in
            await self?.loadEvents(
                currentUserID: currentUserID,
                showsLoading: showsLoading
            )
            await MainActor.run {
                self?.refreshTask = nil
            }
        }
    }

    func loadEvents(currentUserID: UUID?, showsLoading: Bool = false) async {
        guard !isLoading else {
            return
        }

        guard let currentUserID else {
            events = []
            errorMessage = "No authenticated user was found."
            return
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
                return
            }

            let eventIDs = Array(Set(profile.hostedEvents + profile.participatedEvents))
            events = try await eventService.fetchEvents(ids: eventIDs)
        } catch is CancellationError {
            print("MyEventsViewModel: events load was cancelled.")
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeEvent(id: UUID) {
        events.removeAll { $0.id == id }
    }
}
