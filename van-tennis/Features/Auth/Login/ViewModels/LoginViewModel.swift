import Combine
import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
  
    @Published var isSigningIn = false
    @Published var errorMessage: String?
    /**
        The login flow is as follows:
        1. User taps "Continue with Google" button.
        2. `continueWithGoogle` is called, which initiates the Google sign-in flow using `GoogleAuthService`.
        3. After successful Google sign-in, we get a Google JWT token.
        4. We then exchange the Google JWT token with our backend (Supabase) to get a Supabase session (access token and user info).
        5. Finally, we use the Supabase session to find or create a user profile in our database.
    
        This flow ensures that we securely authenticate the user with Google and then manage their session and profile within app's backend.
    */
    private let googleAuthService = GoogleAuthService()
    private let supabaseAuthService = SupabaseAuthService()
    private let profileService = ProfileService()

    func continueWithGoogle(appState: AppState) async {
        isSigningIn = true
        errorMessage = nil
        appState.authenticationState = .signingIn

        do {
            // Google sign-in flow to get Google JWT token
            let googleSession = try await googleAuthService.signIn()

            // Exchange Google JWT token with Supabase to get Supabase session (access token, user info)
            let supabaseSession = try await supabaseAuthService.signInWithGoogle(googleSession)
            
            // Use Supabase session to find or create user profile in database
            let userProfile = try await profileService.findOrCreateProfile(for: supabaseSession.user)

            appState.completeSignIn(
                googleSession: googleSession,
                supabaseSession: supabaseSession,
                userProfile: userProfile
            )
        } catch {
            appState.googleSession = nil
            appState.supabaseSession = nil
            appState.userProfile = nil
            appState.authenticationState = .signedOut
            errorMessage = error.localizedDescription
        }

        isSigningIn = false
    }
}
