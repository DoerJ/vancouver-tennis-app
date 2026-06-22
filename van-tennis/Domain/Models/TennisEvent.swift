import Foundation

struct TennisEvent: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let hostID: UUID
    let startTime: Date
    let endTime: Date
    let eventType: EventType
    let maxPlayers: Int?
    let city: EventCity
    let court: TennisCourt
    let skillLevel: SkillLevel
    let status: EventStatus
    let participants: [UUID]
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case hostID = "host_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case eventType = "event_type"
        case maxPlayers = "max_players"
        case city = "location_city"
        case court = "location_court"
        case skillLevel = "skill_level"
        case status
        case participants
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var playerCount: Int {
        1 + participants.count
    }

    var isFull: Bool {
        guard let maxPlayers else {
            return false
        }

        return playerCount >= maxPlayers
    }
}

struct TennisEventDraft: Equatable {
    var startTime: Date
    var endTime: Date
    var eventType: EventType
    var maxPlayers: Int?
    var city: EventCity
    var court: TennisCourt
    var skillLevel: SkillLevel
}
