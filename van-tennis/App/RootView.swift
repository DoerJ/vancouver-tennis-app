import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch appState.authenticationState {
            case .signedOut, .signingIn:
                LoginView()
            case .signedIn:
                MainTabView()
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
}
