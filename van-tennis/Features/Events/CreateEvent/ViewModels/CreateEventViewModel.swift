import Combine
import Foundation

@MainActor
final class CreateEventViewModel: ObservableObject {
    @Published var startTime: Date
    @Published var endTime: Date
    @Published var eventType: EventType = .practice
    @Published var hasPlayerLimit = true
    @Published var maxPlayers = 2
    @Published var city: EventCity = .burnaby {
        didSet {
            if !city.courts.contains(court) {
                court = city.courts[0]
            }
        }
    }
    @Published var court: TennisCourt = .bcitCourt
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
            maxPlayers: hasPlayerLimit ? maxPlayers : nil,
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

        guard !hasPlayerLimit || maxPlayers >= Constants.Event.minimumPlayerLimit else {
            errorMessage = AppContent.string("events.create.maxPlayersTooLow", Constants.Event.minimumPlayerLimit)
            return false
        }

        guard !hasPlayerLimit || maxPlayers <= Constants.Event.maximumPlayerLimit else {
            errorMessage = AppContent.string("events.create.maxPlayersTooHigh", Constants.Event.maximumPlayerLimit)
            return false
        }

        errorMessage = nil
        return true
    }

    func save(activeHostedEvents: [TennisEvent]) async -> TennisEvent? {
        guard let draft else {
            return nil
        }

        if activeHostedEvents.contains(where: { overlaps(draft: draft, existingEvent: $0) }) {
            errorMessage = AppContent.string("events.create.overlap")
            return nil
        }

        isSaving = true
        errorMessage = nil

        do {
            let event = try await eventService.createEvent(draft)
            isSaving = false
            return event
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return nil
        }
    }

    private func overlaps(draft: TennisEventDraft, existingEvent: TennisEvent) -> Bool {
        draft.startTime < existingEvent.endTime && existingEvent.startTime < draft.endTime
    }
}
