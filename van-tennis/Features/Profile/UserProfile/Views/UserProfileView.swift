import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isSigningOut = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text(appState.userProfile?.displayName ?? "Your tennis profile")
                        .font(.title2)
                        .fontWeight(.semibold)

                    if let skillLevel = appState.userProfile?.skillLevel {
                        Text("Skill level: \(skillLevel.rawValue)")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                if let profile = appState.userProfile {
                    NavigationLink {
                        EditProfileView(profile: profile)
                    } label: {
                        Text("Edit Profile")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

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
