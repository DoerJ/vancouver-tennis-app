import Supabase

enum SupabaseClientProvider {
    static let shared = SupabaseClient(
        supabaseURL: AppConfig.supabaseProjectURL,
        supabaseKey: AppConfig.supabaseAnonKey
    )

    static let chatRealtime = SupabaseClient(
        supabaseURL: AppConfig.supabaseProjectURL,
        supabaseKey: AppConfig.supabaseAnonKey,
        options: SupabaseClientOptions(
            auth: .init(
                accessToken: {
                    try await SupabaseClientProvider.shared.auth.session.accessToken
                }
            )
        )
    )
}
