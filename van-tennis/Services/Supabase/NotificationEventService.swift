import Foundation
import Supabase

struct NotificationEventService {
    private let client = SupabaseClientProvider.shared

    func fetchNotifications(ids notificationIDs: [UUID]) async throws -> [NotificationEvent] {
        guard !notificationIDs.isEmpty else {
            return []
        }

        return try await client
            .from("notifications")
            .select()
            .in("id", values: notificationIDs.map(\.uuidString))
            .order("created_at", ascending: false)
            .execute()
            .value
    }

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
