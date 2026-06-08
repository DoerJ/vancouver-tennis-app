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

    func createEvent(_ draft: TennisEventDraft, hostID: UUID) async throws -> TennisEvent {
        let newEvent = NewTennisEvent(
            hostID: hostID,
            startTime: draft.startTime,
            endTime: draft.endTime,
            eventType: draft.eventType,
            maxPlayers: draft.maxPlayers,
            city: draft.city,
            court: draft.court,
            skillLevel: draft.skillLevel
        )

        return try await client
            .from("tennis_events")
            .insert(newEvent)
            .select()
            .single()
            .execute()
            .value
    }
}
