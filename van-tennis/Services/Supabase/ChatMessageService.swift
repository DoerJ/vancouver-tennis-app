import Foundation
import Supabase

struct ChatMessageService {
    private let client = SupabaseClientProvider.shared

    func fetchMessages(eventID: UUID) async throws -> [ChatMessage] {
        try await client
            .from("chat_messages")
            .select()
            .eq("event_id", value: eventID.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func createMessage(_ message: NewChatMessage) async throws -> ChatMessage {
        try await client
            .from("chat_messages")
            .insert(message)
            .select()
            .single()
            .execute()
            .value
    }
}
