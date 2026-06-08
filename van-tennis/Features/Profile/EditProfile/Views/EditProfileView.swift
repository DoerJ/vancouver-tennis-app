import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var displayName: String
    @State private var skillLevel: SkillLevel
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(profile: UserProfile) {
        _displayName = State(initialValue: profile.displayName)
        _skillLevel = State(initialValue: profile.skillLevel ?? .one)
    }

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Display name", text: $displayName)
                    .textInputAutocapitalization(.words)

                Picker("Skill Level", selection: $skillLevel) {
                    ForEach(SkillLevel.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Edit Profile")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSaving ? "Saving..." : "Save") {
                    Task {
                        await save()
                    }
                }
                .disabled(isSaving || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() async {
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedDisplayName.isEmpty else {
            errorMessage = "Display name is required."
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            try await appState.updateProfile(
                displayName: trimmedDisplayName,
                skillLevel: skillLevel
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}

#Preview {
    NavigationStack {
        EditProfileView(
            profile: UserProfile(
                id: UUID(),
                email: "player@example.com",
                displayName: "Tennis Player",
                avatarURL: nil,
                skillLevel: .three,
                hostedEvents: [],
                createdAt: nil,
                updatedAt: nil
            )
        )
        .environmentObject(AppState())
    }
}
