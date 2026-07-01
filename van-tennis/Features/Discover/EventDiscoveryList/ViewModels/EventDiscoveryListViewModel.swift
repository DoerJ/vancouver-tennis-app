import Combine
import Foundation

@MainActor
final class EventDiscoveryListViewModel: ObservableObject {
    @Published var events: [TennisEvent] = []
    @Published var selectedCityFilter: EventCityFilter = .all
    @Published var selectedSkillLevelFilter: EventSkillLevelFilter = .all
    @Published var selectedEventTypeFilter: EventTypeFilter = .all
    @Published var isLoading = false
    @Published var isLoadingNextPage = false
    @Published var hasMoreEvents = true
    @Published var errorMessage: String?

    private(set) var hasLoadedInitialPage = false
    private var skippedFilterReloadsRemaining = 0
    private let eventService = EventService()

    var filteredEvents: [TennisEvent] {
        events.filter(Self.hasFutureEndTime)
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

        if !selectedEventTypeFilter.matches(event.eventType) {
            filtersToReset += 1
        }

        skippedFilterReloadsRemaining += filtersToReset

        if !selectedCityFilter.matches(event.city) {
            selectedCityFilter = .all
        }

        if !selectedSkillLevelFilter.matches(event.skillLevel) {
            selectedSkillLevelFilter = .all
        }

        if !selectedEventTypeFilter.matches(event.eventType) {
            selectedEventTypeFilter = .all
        }

        events.removeAll { $0.id == event.id }
        if Self.hasFutureEndTime(event) {
            events.append(event)
        }
        events.sort { $0.startTime < $1.startTime }
    }

    func consumeShouldSkipNextFilterReload() -> Bool {
        guard skippedFilterReloadsRemaining > 0 else {
            return false
        }

        skippedFilterReloadsRemaining -= 1
        return true
    }

    func resetFilters() -> Bool {
        var filtersToReset = 0

        if selectedCityFilter != .all {
            filtersToReset += 1
        }

        if selectedSkillLevelFilter != .all {
            filtersToReset += 1
        }

        if selectedEventTypeFilter != .all {
            filtersToReset += 1
        }

        guard filtersToReset > 0 else {
            return false
        }

        skippedFilterReloadsRemaining += filtersToReset
        selectedCityFilter = .all
        selectedSkillLevelFilter = .all
        selectedEventTypeFilter = .all
        return true
    }

    private func appendPage(_ page: [TennisEvent]) {
        for event in page where Self.hasFutureEndTime(event) && !events.contains(where: { $0.id == event.id }) {
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
            let page = try await eventService.fetchEvents(
                from: reset ? 0 : events.count,
                limit: Constants.EventDiscovery.pageSize,
                city: selectedCityFilter.city,
                skillLevel: selectedSkillLevelFilter.skillLevel,
                eventType: selectedEventTypeFilter.eventType
            )

            if reset {
                events = page.filter(Self.hasFutureEndTime)
                hasLoadedInitialPage = true
            } else {
                appendPage(page)
            }

            hasMoreEvents = page.count == Constants.EventDiscovery.pageSize
        } catch {
            errorMessage = error.localizedDescription
        }

        if reset {
            isLoading = false
        } else {
            isLoadingNextPage = false
        }
    }

    private static func hasFutureEndTime(_ event: TennisEvent) -> Bool {
        event.endTime > Date()
    }
}

enum EventTypeFilter: Hashable, Identifiable {
    case all
    case eventType(EventType)

    var id: String {
        switch self {
        case .all:
            return "all"
        case .eventType(let eventType):
            return eventType.rawValue
        }
    }

    var displayName: String {
        switch self {
        case .all:
            return "All"
        case .eventType(let eventType):
            return eventType.displayName
        }
    }

    var eventType: EventType? {
        switch self {
        case .all:
            return nil
        case .eventType(let eventType):
            return eventType
        }
    }

    func matches(_ eventType: EventType) -> Bool {
        switch self {
        case .all:
            return true
        case .eventType(let selectedEventType):
            return selectedEventType == eventType
        }
    }

    static let options: [EventTypeFilter] = [
        .all,
        .eventType(.practice),
        .eventType(.casual),
        .eventType(.match)
    ]
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
