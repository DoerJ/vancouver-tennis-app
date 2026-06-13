import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isSigningOut = false
    @State private var isDeletingAccount = false
    @State private var isShowingDeleteAccountConfirmation = false
    @State private var isShowingAccountDeletedAlert = false
    @State private var deleteAccountErrorMessage: String?

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

                    if let gender = appState.userProfile?.gender {
                        Text("Gender: \(gender.displayName)")
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

                if let deleteAccountErrorMessage {
                    Text(deleteAccountErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
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

                Button(role: .destructive) {
                    isShowingDeleteAccountConfirmation = true
                } label: {
                    Text(isDeletingAccount ? "Deleting account..." : "Delete Account")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isDeletingAccount)
            }
            .padding()
            .navigationTitle("Profile")
            .confirmationDialog(
                "Delete your account?",
                isPresented: $isShowingDeleteAccountConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    Task {
                        await prepareAccountDeletion()
                    }
                }

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone.")
            }
            .alert("Account Deleted", isPresented: $isShowingAccountDeletedAlert) {
                Button("OK") {
                    appState.finishDeletedAccountFlow()
                }
            } message: {
                Text("Your account has been successfully deleted.")
            }
        }
    }

    private func prepareAccountDeletion() async {
        isDeletingAccount = true
        deleteAccountErrorMessage = nil

        do {
            try await appState.deleteAccountProfileDataAndRevokeSession()
            isShowingAccountDeletedAlert = true
        } catch {
            deleteAccountErrorMessage = error.localizedDescription
        }

        isDeletingAccount = false
    }
}

#Preview {
    UserProfileView()
        .environmentObject(AppState())
}
