import Foundation
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @State private var hasRestoredSession = false

    var body: some View {
        Group {
            if hasRestoredSession {
                switch appState.authenticationState {
                case .signedOut, .signingIn:
                    LoginView()
                case .needsSkillLevel:
                    OnboardingProfileView()
                case .signedIn:
                    MainTabView()
                }
            } else {
                AppLoadingView()
            }
        }
        .appLanguageFontStyle(appState.contentLanguage)
        .onOpenURL { url in
            appState.handleIncomingUniversalLink(url)
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            guard let url = activity.webpageURL else {
                return
            }

            appState.handleIncomingUniversalLink(url)
        }
        .task {
            guard !hasRestoredSession else {
                return
            }

            await appState.restoreExistingSession()
            hasRestoredSession = true
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
}
