import Supabase

enum SupabaseClientProvider {
    static let shared = SupabaseClient(
        supabaseURL: AppConfig.supabaseProjectURL,
        supabaseKey: AppConfig.supabaseAnonKey
    )
}
