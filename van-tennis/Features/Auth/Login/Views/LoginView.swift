import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = LoginViewModel()

    var body: some View {
        ZStack {
            Image("login_caption")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 12) {
                    authButton(
                        iconName: "google",
                        title: viewModel.isSigningIn
                            ? AppContent.string("auth.login.signingIn")
                            : AppContent.string("auth.login.continueWithGoogle")
                    ) {
                        Task {
                            await viewModel.continueWithGoogle(appState: appState)
                        }
                    }

                    authButton(
                        iconName: "apple-icon",
                        title: AppContent.string("auth.login.continueWithApple")
                    ) {
                        Task {
                            await viewModel.continueWithApple(appState: appState)
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.rally(size: 13))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()
                    .frame(height: 44)
            }
            .padding(24)
        }
    }

    private func authButton(
        iconName: String,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)

                Text(title)
            }
            .font(.rally(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(height: 52)
            .frame(maxWidth: .infinity)
            .background(
                Color.black.opacity(viewModel.isSigningIn ? 0.28 : 1),
                in: Capsule()
            )
            .shadow(color: RallyDiscoverStyle.shadow.opacity(viewModel.isSigningIn ? 0 : 0.95), radius: 18, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSigningIn)
    }
}

#Preview {
    LoginView()
        .environmentObject(AppState())
}
