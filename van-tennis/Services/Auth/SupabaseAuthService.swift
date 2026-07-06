import Foundation
import Supabase

struct SupabaseAuthService {
    // Pass the GoogleAuthSession (which contains the Google JWT token) to this method to exchange it for a Supabase session (access token, user info).
    func signInWithGoogle(_ googleSession: GoogleAuthSession) async throws -> Session {
        guard AppConfig.isSupabaseConfigured else {
            throw SupabaseAuthError.missingSupabaseConfiguration
        }

        guard let idToken = googleSession.idToken else {
            throw SupabaseAuthError.missingGoogleIDToken
        }

        return try await SupabaseClientProvider.shared.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .google,
                idToken: idToken,
                accessToken: googleSession.accessToken
            )
        )
    }

    func signOut() async throws {
        try await SupabaseClientProvider.shared.auth.signOut()
    }
}

enum SupabaseAuthError: LocalizedError {
    case missingSupabaseConfiguration
    case missingGoogleIDToken

    var errorDescription: String? {
        switch self {
        case .missingSupabaseConfiguration:
            return AppContent.string("auth.login.missingSupabaseConfiguration")
        case .missingGoogleIDToken:
            return AppContent.string("auth.login.missingGoogleIDToken")
        }
    }
}
