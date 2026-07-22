import Foundation
import Supabase

struct BlacklistService {
    private let client = SupabaseClientProvider.shared

    func isCurrentUserEmailBlacklisted() async throws -> Bool {
        try await client
            .rpc("current_user_email_is_blacklisted")
            .execute()
            .value
    }
}
