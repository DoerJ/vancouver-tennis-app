import Combine
import Foundation

@MainActor
final class EventDiscoveryListViewModel: ObservableObject {
    @Published var events: [TennisEvent] = []
    @Published var selectedCityFilter: EventCityFilter = .all
    @Published var selectedSkillLevelFilter: EventSkillLevelFilter = .all
    @Published var isLoading = false
    @Published var isLoadingNextPage = false
    @Published var hasMoreEvents = true
    @Published var errorMessage: String?

    private(set) var hasLoadedInitialPage = false
    private var skippedFilterReloadsRemaining = 0
    // The number of events to load per page when paginating
    private let pageSize = 10
    private let eventService = EventService()

    var filteredEvents: [TennisEvent] {
        events
    }

    func loadEvents() async {
        await loadPage(reset: true)
    }

    func loadInitialEventsIfNeeded() async {
        guard !hasLoadedInitialPage else {
            return
        }

        await loadEvents()
    }

    func loadNextPage() async {
        await loadPage(reset: false)
    }

    func applyCreatedEvent(_ event: TennisEvent) {
        var filtersToReset = 0

        if !selectedCityFilter.matches(event.city) {
            filtersToReset += 1
        }

        if !selectedSkillLevelFilter.matches(event.skillLevel) {
            filtersToReset += 1
        }

        skippedFilterReloadsRemaining += filtersToReset

        if !selectedCityFilter.matches(event.city) {
            selectedCityFilter = .all
        }

        if !selectedSkillLevelFilter.matches(event.skillLevel) {
            selectedSkillLevelFilter = .all
        }

        events.removeAll { $0.id == event.id }
        events.append(event)
        events.sort { $0.startTime < $1.startTime }
    }

    func consumeShouldSkipNextFilterReload() -> Bool {
        guard skippedFilterReloadsRemaining > 0 else {
            return false
        }

        skippedFilterReloadsRemaining -= 1
        return true
    }

    private func appendPage(_ page: [TennisEvent]) {
        for event in page where !events.contains(where: { $0.id == event.id }) {
            events.append(event)
        }

        events.sort { $0.startTime < $1.startTime }
    }

    private func loadPage(reset: Bool) async {
        guard !isLoading, !isLoadingNextPage else {
            return
        }

        if !reset {
            guard hasMoreEvents else {
                return
            }

            isLoadingNextPage = true
        } else {
            isLoading = true
            events = []
            hasMoreEvents = true
        }

        errorMessage = nil

        do {
            if reset {
                try await eventService.deleteExpiredEvents()
            }

            let page = try await eventService.fetchEvents(
                from: reset ? 0 : events.count,
                limit: pageSize,
                city: selectedCityFilter.city,
                skillLevel: selectedSkillLevelFilter.skillLevel
            )

            if reset {
                events = page
                hasLoadedInitialPage = true
            } else {
                appendPage(page)
            }

            hasMoreEvents = page.count == pageSize
        } catch {
            errorMessage = error.localizedDescription
        }

        if reset {
            isLoading = false
        } else {
            isLoadingNextPage = false
        }
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

enum EventSkillLevelFilter: Hashable, Identifiable {
    case all
    case skillLevel(SkillLevel)

    var id: String {
        switch self {
        case .all:
            return "all"
        case .skillLevel(let skillLevel):
            return skillLevel.rawValue
        }
    }

    var displayName: String {
        switch self {
        case .all:
            return "All"
        case .skillLevel(let skillLevel):
            return skillLevel.rawValue
        }
    }

    var skillLevel: SkillLevel? {
        switch self {
        case .all:
            return nil
        case .skillLevel(let skillLevel):
            return skillLevel
        }
    }

    func matches(_ skillLevel: SkillLevel) -> Bool {
        switch self {
        case .all:
            return true
        case .skillLevel(let selectedSkillLevel):
            return selectedSkillLevel == skillLevel
        }
    }

    static let options: [EventSkillLevelFilter] = [
        .all,
        .skillLevel(.one),
        .skillLevel(.two),
        .skillLevel(.three),
        .skillLevel(.four)
    ]
}
