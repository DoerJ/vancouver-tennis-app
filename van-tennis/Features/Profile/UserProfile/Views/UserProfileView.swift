import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isSigningOut = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(appState.userProfile?.displayName ?? "Your tennis profile")
                    .font(.title2)
                    .fontWeight(.semibold)

                Button(role: .destructive) {
                    Task {
                        isSigningOut = true
                        await appState.signOut()
                        isSigningOut = false
                    }
                } label: {
                    Text(isSigningOut ? "Signing out..." : "Log Out")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isSigningOut)
            }
            .padding()
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    UserProfileView()
        .environmentObject(AppState())
}
