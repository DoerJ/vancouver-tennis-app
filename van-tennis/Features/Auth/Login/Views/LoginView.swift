import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = LoginViewModel()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("Van Tennis")
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                Text("Sign in to find and manage tennis matches.")
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
                    Text(viewModel.isSigningIn ? "Signing in..." : "Continue with Google")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
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
