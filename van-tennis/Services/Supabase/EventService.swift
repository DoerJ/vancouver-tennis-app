import Foundation
import Supabase

struct EventService {
    private let client = SupabaseClientProvider.shared

    func createEvent(_ draft: TennisEventDraft, hostID: UUID) async throws {
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

        try await client
            .from("tennis_events")
            .insert(newEvent)
            .execute()
    }
}
