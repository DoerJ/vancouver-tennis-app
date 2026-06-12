import Foundation
import Supabase

struct EventService {
    private let client = SupabaseClientProvider.shared

    func fetchEvents(from startIndex: Int, limit: Int, city: EventCity? = nil) async throws -> [TennisEvent] {
        let endIndex = startIndex + limit - 1

        if let city {
            return try await client
                .from("tennis_events")
                .select()
                .eq("location_city", value: city.rawValue)
                .order("start_time", ascending: true)
                .range(from: startIndex, to: endIndex)
                .execute()
                .value
        }

        return try await client
            .from("tennis_events")
            .select()
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

    func createEvent(_ draft: TennisEventDraft, hostID: UUID) async throws -> TennisEvent {
        let newEvent = NewTennisEvent(
            hostID: hostID,
            startTime: draft.startTime,
            endTime: draft.endTime,
            eventType: draft.eventType,
            maxPlayers: draft.maxPlayers,
            city: draft.city,
            court: draft.court,
            skillLevel: draft.skillLevel,
            participants: []
        )

        return try await client
            .from("tennis_events")
            .insert(newEvent)
            .select()
            .single()
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

    func leaveEvent(eventID: UUID) async throws {
        try await client
            .rpc(
                "leave_event",
                params: LeaveEventParams(eventID: eventID)
            )
            .execute()
    }

    func deleteExpiredEvents() async throws {
        try await client
            .rpc("delete_expired_events")
            .execute()
    }
}

private struct LeaveEventParams: Encodable {
    let eventID: UUID

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
    }
}
