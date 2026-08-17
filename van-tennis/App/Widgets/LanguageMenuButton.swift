import SwiftUI

struct LanguageMenuButton: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Menu {
            Button {
                appState.setContentLanguage(.english)
            } label: {
                Label("English", systemImage: appState.contentLanguage == .english ? "checkmark" : "")
            }

            Button {
                appState.setContentLanguage(.mandarinSimplified)
            } label: {
                Label("中文", systemImage: appState.contentLanguage == .mandarinSimplified ? "checkmark" : "")
            }
        } label: {
            Image("language")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Language")
    }
}
