import Foundation
import Supabase

struct DeviceTokenService {
    private let client = SupabaseClientProvider.shared

    func saveDeviceToken(userID: UUID, deviceToken: String) async throws {
        let newDeviceToken = NewDeviceToken(
            userID: userID,
            deviceToken: deviceToken,
            platform: "ios"
        )

        try await client
            .from("device_tokens")
            .upsert(
                newDeviceToken,
                onConflict: "user_id,device_token",
                ignoreDuplicates: false
            )
            .execute()
    }
}
