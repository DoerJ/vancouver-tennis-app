import Combine
import Foundation

@MainActor
final class MyEventsViewModel: ObservableObject {
    @Published var events: [TennisEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let eventService = EventService()

    func loadEvents(hostedEventIDs: [UUID]) async {
        isLoading = true
        errorMessage = nil

        do {
            events = try await eventService.fetchEvents(ids: hostedEventIDs)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
