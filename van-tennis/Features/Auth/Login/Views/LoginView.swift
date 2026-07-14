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

                Button {
                    Task {
                        await viewModel.continueWithGoogle(appState: appState)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image("google")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)

                        Text(
                            viewModel.isSigningIn
                                ? AppContent.string("auth.login.signingIn")
                            : AppContent.string("auth.login.continueWithGoogle")
                        )
                    }
                    .font(.system(size: 15, weight: .semibold))
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

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()
                    .frame(height: 44)
            }
            .padding(24)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AppState())
}
