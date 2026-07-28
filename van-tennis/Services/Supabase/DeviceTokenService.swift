import Foundation
import Supabase

struct DeviceTokenService {
    private let client = SupabaseClientProvider.shared

    func saveDeviceToken(userID: UUID, deviceToken: String) async throws {
        print("DeviceTokenService: upserting device token. userID=\(userID), tokenSuffix=\(deviceToken.suffix(8)), conflict=user_id,platform.")

        let newDeviceToken = NewDeviceToken(
            userID: userID,
            deviceToken: deviceToken,
            platform: "ios"
        )

        try await client
            .from("device_tokens")
            .upsert(
                newDeviceToken,
                onConflict: "user_id,platform",
                ignoreDuplicates: false
            )
            .execute()

        print("DeviceTokenService: device token upsert completed. userID=\(userID), tokenSuffix=\(deviceToken.suffix(8)).")
    }

}
