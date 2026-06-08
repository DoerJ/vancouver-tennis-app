import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch appState.authenticationState {
            case .signedOut, .signingIn:
                LoginView()
            case .needsSkillLevel:
                OnboardingProfileView()
            case .signedIn:
                MainTabView()
            }
        }
        .task {
            await appState.restoreExistingSession()
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
}
