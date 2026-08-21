import Foundation

enum AppConfig {
    // The configuration values are read from Info.plist
    static let supabaseProjectURL: URL = {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "SupabaseProjectURL") as? String,
              let url = URL(string: value) else {
            fatalError("Missing or invalid SupabaseProjectURL in Info.plist")
        }

        return url
    }()

    static let supabaseAnonKey: String = {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String else {
            fatalError("Missing SupabaseAnonKey in Info.plist")
        }

        return value
    }()

    static let googleClientID: String = {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String else {
            fatalError("Missing GoogleClientID in Info.plist")
        }

        return value
    }()

    static let googleAuthorizationEndpoint: URL = {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "GoogleAuthorizationEndpoint") as? String,
              let url = URL(string: value) else {
            fatalError("Missing or invalid GoogleAuthorizationEndpoint in Info.plist")
        }

        return url
    }()

    static let googleTokenEndpoint: URL = {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "GoogleTokenEndpoint") as? String,
              let url = URL(string: value) else {
            fatalError("Missing or invalid GoogleTokenEndpoint in Info.plist")
        }

        return url
    }()

    static let googleReversedClientID: String = {
        // The reversed client ID is used for the URL scheme in ASWebAuthenticationSession callback
        // It should be in the format "com.googleusercontent.apps.YOUR_CLIENT_ID"
        let reversed = googleClientID
            .replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
            .split(separator: ".")
            .reversed()
            .joined(separator: ".")
        return "com.googleusercontent.apps.\(reversed)"
    }()

    static var isSupabaseConfigured: Bool {
        supabaseProjectURL.host != "YOUR_SUPABASE_PROJECT.supabase.co"
            && supabaseAnonKey != "YOUR_SUPABASE_ANON_KEY"
    }

    static let profileAvatarStoragePath: String = {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "ProfileAvatarStoragePath") as? String else {
            fatalError("Missing ProfileAvatarStoragePath in Info.plist")
        }

        let path = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            fatalError("ProfileAvatarStoragePath cannot be empty")
        }

        return path
    }()
}
