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
        startTime = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
        endTime = Calendar.current.date(byAdding: .hour, value: 2, to: now) ?? now
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

    func validate() -> Bool {
        guard endTime > startTime else {
            errorMessage = "End time must be after start time."
            return false
        }

        guard !hasPlayerLimit || maxPlayers > 0 else {
            errorMessage = "Max players must be at least 1."
            return false
        }

        errorMessage = nil
        return true
    }

    func save(hostID: UUID) async -> TennisEvent? {
        guard let draft else {
            return nil
        }

        isSaving = true
        errorMessage = nil

        do {
            let event = try await eventService.createEvent(draft, hostID: hostID)
            isSaving = false
            return event
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return nil
        }
    }
}
