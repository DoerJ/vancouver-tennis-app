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

    func fetchNotifications(recipientID: UUID) async throws -> [NotificationEvent] {
        try await client
            .from("notifications")
            .select()
            .contains("recipients", value: [recipientID.uuidString])
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

    func deleteNotificationForCurrentUser(notificationID: UUID) async throws {
        /*
            Perform a Supasbase RPC call to delete the notification for the current user.
            - The RPC function will remove the notification ID from the user's profile `notifications` array.
            - The RPC function will take care of removing the user's ID from the `recipients` array of the notification.
            - If the `recipients` array becomes empty after removal, the RPC function will delete the notification entirely from the database.
        */
        try await client
            .rpc(
                "delete_notification_for_current_user",
                params: DeleteNotificationForCurrentUserParams(notificationID: notificationID)
            )
            .execute()
    }

    func approveJoinRequest(notificationID: UUID) async throws {
        try await client
            .rpc(
                "approve_join_request",
                params: ApproveJoinRequestParams(notificationID: notificationID)
            )
            .execute()
    }
}

private struct DeleteNotificationForCurrentUserParams: Encodable {
    let notificationID: UUID

    enum CodingKeys: String, CodingKey {
        case notificationID = "notification_id"
    }
}

private struct ApproveJoinRequestParams: Encodable {
    let notificationID: UUID

    enum CodingKeys: String, CodingKey {
        case notificationID = "notification_id"
    }
}
