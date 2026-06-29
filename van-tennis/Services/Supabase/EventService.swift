import Foundation
import Supabase

struct EventService {
    private let client = SupabaseClientProvider.shared

    func fetchEvents(
        from startIndex: Int,
        limit: Int,
        city: EventCity? = nil,
        skillLevel: SkillLevel? = nil,
        eventType: EventType? = nil
    ) async throws -> [TennisEvent] {
        let endIndex = startIndex + limit - 1
        let currentTime = Self.supabaseTimestampFormatter.string(from: Date())
        var query = client
            .from("tennis_events")
            .select()
            .gt("end_time", value: currentTime)

        if let city {
            query = query.eq("location_city", value: city.rawValue)
        }

        if let skillLevel {
            query = query.eq("skill_level", value: skillLevel.rawValue)
        }

        if let eventType {
            query = query.eq("event_type", value: eventType.rawValue)
        }

        return try await query
            .order("start_time", ascending: true)
            .range(from: startIndex, to: endIndex)
            .execute()
            .value
    }

    func fetchEvents(ids eventIDs: [UUID]) async throws -> [TennisEvent] {
        guard !eventIDs.isEmpty else {
            return []
        }

        return try await client
            .from("tennis_events")
            .select()
            .in("id", values: eventIDs.map(\.uuidString))
            .order("start_time", ascending: true)
            .execute()
            .value
    }

    func fetchEventDetails(id eventID: UUID) async throws -> TennisEvent? {
        let events: [TennisEvent] = try await client
            .from("tennis_events")
            .select()
            .eq("id", value: eventID.uuidString)
            .limit(1)
            .execute()
            .value

        return events.first
    }

    func createEvent(_ draft: TennisEventDraft) async throws -> TennisEvent {
        try await client
            .rpc(
                "create_tennis_event",
                params: CreateTennisEventParams(draft: draft)
            )
            .execute()
            .value
    }

    func deleteEvent(eventID: UUID, hostID: UUID) async throws {
        try await client
            .from("tennis_events")
            .delete()
            .eq("id", value: eventID.uuidString)
            .eq("host_id", value: hostID.uuidString)
            .execute()
    }

    func cancelHostedEvent(eventID: UUID) async throws {
        try await client
            .rpc(
                "cancel_hosted_event",
                params: CancelHostedEventParams(eventID: eventID)
            )
            .execute()
    }

    func leaveEvent(eventID: UUID) async throws {
        try await client
            .rpc(
                "leave_event",
                params: LeaveEventParams(eventID: eventID)
            )
            .execute()
    }

    func updateMaxPlayers(eventID: UUID, maxPlayers: Int?) async throws -> TennisEvent {
        try await client
            .rpc(
                "update_event_max_players",
                params: UpdateEventMaxPlayersParams(
                    eventID: eventID,
                    maxPlayers: maxPlayers
                )
            )
            .execute()
            .value
    }

    func deleteExpiredEvents() async throws {
        try await client
            .rpc("delete_expired_events")
            .execute()
    }

    func cancelHostedEventsForAccountDeletion() async throws {
        try await client
            .rpc("cancel_hosted_events_for_account_deletion")
            .execute()
    }

    private static let supabaseTimestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private struct LeaveEventParams: Encodable {
    let eventID: UUID

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
    }
}

private struct UpdateEventMaxPlayersParams: Encodable {
    let eventID: UUID
    let maxPlayers: Int?

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case maxPlayers = "new_max_players"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventID, forKey: .eventID)

        if let maxPlayers {
            try container.encode(maxPlayers, forKey: .maxPlayers)
        } else {
            try container.encodeNil(forKey: .maxPlayers)
        }
    }
}

private struct CancelHostedEventParams: Encodable {
    let eventID: UUID

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
    }
}

private struct CreateTennisEventParams: Encodable {
    let startTime: Date
    let endTime: Date
    let eventType: EventType
    let maxPlayers: Int?
    let city: EventCity
    let court: TennisCourt
    let skillLevel: SkillLevel

    init(draft: TennisEventDraft) {
        startTime = draft.startTime
        endTime = draft.endTime
        eventType = draft.eventType
        maxPlayers = draft.maxPlayers
        city = draft.city
        court = draft.court
        skillLevel = draft.skillLevel
    }

    enum CodingKeys: String, CodingKey {
        case startTime = "p_start_time"
        case endTime = "p_end_time"
        case eventType = "p_event_type"
        case maxPlayers = "p_max_players"
        case city = "p_location_city"
        case court = "p_location_court"
        case skillLevel = "p_skill_level"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(eventType, forKey: .eventType)

        if let maxPlayers {
            try container.encode(maxPlayers, forKey: .maxPlayers)
        } else {
            try container.encodeNil(forKey: .maxPlayers)
        }

        try container.encode(city, forKey: .city)
        try container.encode(court, forKey: .court)
        try container.encode(skillLevel, forKey: .skillLevel)
    }
}
