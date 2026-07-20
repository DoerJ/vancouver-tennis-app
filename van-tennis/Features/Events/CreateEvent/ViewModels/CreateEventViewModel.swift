import Combine
import Foundation

@MainActor
final class CreateEventViewModel: ObservableObject {
    @Published var startTime: Date
    @Published var endTime: Date
    @Published var eventType: EventType = .practice
    @Published var maxPlayers = 2
    @Published var city: EventCity = .burnaby {
        didSet {
            if let firstCourt = city.courts.first {
                court = firstCourt
            }
        }
    }
    @Published var court: TennisCourt = EventCity.burnaby.courts.first ?? .bcitCourt
    @Published var errorMessage: String?
    @Published var isSaving = false

    let creatorSkillLevel: SkillLevel
    private let eventService = EventService()

    init(creatorSkillLevel: SkillLevel) {
        self.creatorSkillLevel = creatorSkillLevel

        let now = Date()
        let defaultStartTime = Calendar.current.date(
            byAdding: .hour,
            value: Constants.Event.defaultStartOffsetHours,
            to: now
        ) ?? now
        startTime = defaultStartTime
        endTime = Calendar.current.date(
            byAdding: .hour,
            value: Constants.Event.defaultDurationHours,
            to: defaultStartTime
        ) ?? defaultStartTime
    }

    var draft: TennisEventDraft? {
        guard validate() else {
            return nil
        }

        return TennisEventDraft(
            startTime: startTime,
            endTime: endTime,
            eventType: eventType,
            maxPlayers: maxPlayers,
            city: city,
            court: court,
            skillLevel: creatorSkillLevel
        )
    }

    var latestAllowedStartTime: Date {
        Calendar.current.date(
            byAdding: .day,
            value: Constants.Event.creationWindowDays,
            to: Date()
        ) ?? Date()
    }

    var earliestAllowedStartTime: Date {
        Calendar.current.date(
            byAdding: .hour,
            value: Constants.Event.minimumStartOffsetHours,
            to: Date()
        ) ?? Date()
    }

    var earliestAllowedEndTime: Date {
        Calendar.current.date(
            byAdding: .minute,
            value: Constants.Event.minimumDurationMinutes,
            to: startTime
        ) ?? startTime
    }

    var latestAllowedEndTime: Date {
        Calendar.current.date(
            byAdding: .hour,
            value: Constants.Event.maximumDurationHours,
            to: startTime
        ) ?? startTime
    }

    func validate() -> Bool {
        let now = Date()
        let earliestAllowedStartTime = Calendar.current.date(
            byAdding: .hour,
            value: Constants.Event.minimumStartOffsetHours,
            to: now
        ) ?? now
        let latestAllowedStartTime = Calendar.current.date(
            byAdding: .day,
            value: Constants.Event.creationWindowDays,
            to: now
        ) ?? now

        guard startTime >= earliestAllowedStartTime else {
            errorMessage = AppContent.string("events.create.startTooSoon", Constants.Event.minimumStartOffsetHours)
            return false
        }

        guard startTime <= latestAllowedStartTime else {
            errorMessage = AppContent.string("events.create.startTooFar", Constants.Event.creationWindowDays)
            return false
        }

        guard endTime >= earliestAllowedEndTime else {
            errorMessage = AppContent.string("events.create.endTooSoon", Constants.Event.minimumDurationMinutes)
            return false
        }

        guard endTime <= latestAllowedEndTime else {
            errorMessage = AppContent.string("events.create.endTooFar", Constants.Event.maximumDurationHours)
            return false
        }

        guard maxPlayers >= Constants.Event.minimumPlayerLimit else {
            errorMessage = AppContent.string("events.create.maxPlayersTooLow", Constants.Event.minimumPlayerLimit)
            return false
        }

        guard maxPlayers <= Constants.Event.maximumPlayerLimit else {
            errorMessage = AppContent.string("events.create.maxPlayersTooHigh", Constants.Event.maximumPlayerLimit)
            return false
        }

        errorMessage = nil
        return true
    }

    func createEvent(appState: AppState) async -> TennisEvent? {
        guard !isSaving else {
            return nil
        }

        guard appState.supabaseSession != nil else {
            return nil
        }

        isSaving = true
        errorMessage = nil
        defer {
            isSaving = false
        }

        do {
            let activeHostedEvents = try await appState.activeHostedEventsForCurrentUser()
            guard let event = try await save(activeHostedEvents: activeHostedEvents) else {
                return nil
            }

            appState.updateCachedEvents([event])
            try await appState.appendHostedEvent(event.id)
            return event
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func save(activeHostedEvents: [TennisEvent]) async throws -> TennisEvent? {
        guard let draft else {
            return nil
        }

        if activeHostedEvents.contains(where: { overlaps(draft: draft, existingEvent: $0) }) {
            errorMessage = AppContent.string("events.create.overlap")
            return nil
        }

        return try await eventService.createEvent(draft)
    }

    private func overlaps(draft: TennisEventDraft, existingEvent: TennisEvent) -> Bool {
        draft.startTime < existingEvent.endTime && existingEvent.startTime < draft.endTime
    }
}
