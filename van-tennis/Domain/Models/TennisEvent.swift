import Foundation

struct TennisEventDraft: Equatable {
    var startTime: Date
    var endTime: Date
    var eventType: EventType
    var maxPlayers: Int?
    var city: EventCity
    var court: TennisCourt
    var skillLevel: SkillLevel
}

struct NewTennisEvent: Encodable {
    let hostID: UUID
    let startTime: Date
    let endTime: Date
    let eventType: EventType
    let maxPlayers: Int?
    let city: EventCity
    let court: TennisCourt
    let skillLevel: SkillLevel

    enum CodingKeys: String, CodingKey {
        case hostID = "host_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case eventType = "event_type"
        case maxPlayers = "max_players"
        case city = "location_city"
        case court = "location_court"
        case skillLevel = "skill_level"
    }
}
