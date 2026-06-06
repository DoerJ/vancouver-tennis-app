import Combine
import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var isSigningIn = false
    @Published var errorMessage: String?

    private let googleAuthService = GoogleAuthService()

    func continueWithGoogle(appState: AppState) async {
        isSigningIn = true
        errorMessage = nil
        appState.authenticationState = .signingIn

        do {
            let session = try await googleAuthService.signIn()
            appState.googleSession = session
            appState.authenticationState = .signedIn
        } catch {
            appState.googleSession = nil
            appState.authenticationState = .signedOut
            errorMessage = error.localizedDescription
        }

        isSigningIn = false
    }
}
