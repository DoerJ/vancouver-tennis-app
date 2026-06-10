import Foundation
import Supabase

struct NotificationEventService {
    private let client = SupabaseClientProvider.shared

    func createNotification(_ notification: NewNotificationEvent) async throws -> NotificationEvent {
        try await client
            .from("notifications")
            .insert(notification)
            .select()
            .single()
            .execute()
            .value
    }
}
