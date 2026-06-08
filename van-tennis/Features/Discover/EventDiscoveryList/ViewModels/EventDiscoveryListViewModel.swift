import Combine
import Foundation

@MainActor
final class EventDiscoveryListViewModel: ObservableObject {
    @Published var events: [TennisEvent] = []
    @Published var selectedCityFilter: EventCityFilter = .all
    @Published var isLoading = false
    @Published var isLoadingNextPage = false
    @Published var hasMoreEvents = true
    @Published var errorMessage: String?

    private let pageSize = 10
    private let eventService = EventService()

    var filteredEvents: [TennisEvent] {
        events
    }

    func loadEvents() async {
        events = []
        hasMoreEvents = true
        await loadFirstPage()
    }

    func loadFirstPage() async {
        isLoading = true
        errorMessage = nil

        do {
            let page = try await eventService.fetchEvents(
                from: 0,
                limit: pageSize,
                city: selectedCityFilter.city
            )
            events = page
            hasMoreEvents = page.count == pageSize
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadNextPage() async {
        guard hasMoreEvents, !isLoading, !isLoadingNextPage else {
            return
        }

        isLoadingNextPage = true
        errorMessage = nil

        do {
            let page = try await eventService.fetchEvents(
                from: events.count,
                limit: pageSize,
                city: selectedCityFilter.city
            )
            appendPage(page)
            hasMoreEvents = page.count == pageSize
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingNextPage = false
    }

    func applyCreatedEvent(_ event: TennisEvent) {
        guard selectedCityFilter.matches(event.city) else {
            return
        }

        events.removeAll { $0.id == event.id }
        events.append(event)
        events.sort { $0.startTime < $1.startTime }
    }

    private func appendPage(_ page: [TennisEvent]) {
        for event in page where !events.contains(where: { $0.id == event.id }) {
            events.append(event)
        }

        events.sort { $0.startTime < $1.startTime }
    }
}

enum EventCityFilter: Hashable, Identifiable {
    case all
    case city(EventCity)

    var id: String {
        switch self {
        case .all:
            return "all"
        case .city(let city):
            return city.rawValue
        }
    }

    var displayName: String {
        switch self {
        case .all:
            return "All"
        case .city(let city):
            return city.displayName
        }
    }

    var city: EventCity? {
        switch self {
        case .all:
            return nil
        case .city(let city):
            return city
        }
    }

    func matches(_ city: EventCity) -> Bool {
        switch self {
        case .all:
            return true
        case .city(let selectedCity):
            return selectedCity == city
        }
    }

    static let options: [EventCityFilter] = [
        .all,
        .city(.richmond),
        .city(.burnaby)
    ]
}
