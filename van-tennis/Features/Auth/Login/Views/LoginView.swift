import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = LoginViewModel()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text(AppContent.string("app.name"))
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                Text(AppContent.string("auth.login.subtitle"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button {
                Task {
                    await viewModel.continueWithGoogle(appState: appState)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                    Text(
                        viewModel.isSigningIn
                            ? AppContent.string("auth.login.signingIn")
                            : AppContent.string("auth.login.continueWithGoogle")
                    )
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(viewModel.isSigningIn ? .gray : .accentColor)
            .disabled(viewModel.isSigningIn)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
    }
}

#Preview {
    LoginView()
        .environmentObject(AppState())
}
