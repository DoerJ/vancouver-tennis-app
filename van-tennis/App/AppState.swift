import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var authenticationState: AuthenticationState = .signedOut
    @Published var googleSession: GoogleAuthSession?
}

enum AuthenticationState {
    case signedOut
    case signingIn
    case signedIn
}
