import Combine
import Foundation
import Supabase

@MainActor
final class AppState: ObservableObject {
    @Published var authenticationState: AuthenticationState = .signedOut
    @Published var googleSession: GoogleAuthSession?
    @Published var supabaseSession: Session?
    @Published var userProfile: UserProfile?

    private let profileService = ProfileService()
    private let authService = SupabaseAuthService()

    func restoreExistingSession() async {
        guard AppConfig.isSupabaseConfigured else {
            authenticationState = .signedOut
            return
        }

        do {
            let session = try await SupabaseClientProvider.shared.auth.session
            let profile = try await profileService.findOrCreateProfile(for: session.user)

            supabaseSession = session
            userProfile = profile
            authenticationState = .signedIn
        } catch {
            supabaseSession = nil
            userProfile = nil
            authenticationState = .signedOut
        }
    }

    func signOut() async {
        do {
            try await authService.signOut()
        } catch {
            // Local auth state should still be cleared if remote sign-out fails.
        }

        googleSession = nil
        supabaseSession = nil
        userProfile = nil
        authenticationState = .signedOut
    }
}

enum AuthenticationState {
    case signedOut
    case signingIn
    case signedIn
}
