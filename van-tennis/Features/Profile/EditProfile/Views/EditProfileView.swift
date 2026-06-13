import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var displayName: String
    @State private var skillLevel: SkillLevel
    @State private var selectedSocialTags: Set<String>
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let socialTagOptions = ["intj", "enfp", "software engineer"]

    init(profile: UserProfile) {
        _displayName = State(initialValue: profile.displayName)
        _skillLevel = State(initialValue: profile.skillLevel ?? .one)
        _selectedSocialTags = State(initialValue: Set(profile.socialTags))
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

            Section("Social Tags") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(socialTagOptions, id: \.self) { tag in
                            Button {
                                toggleSocialTag(tag)
                            } label: {
                                HStack(spacing: 6) {
                                    Text(tag)
                                        .font(.subheadline)

                                    if selectedSocialTags.contains(tag) {
                                        Image(systemName: "checkmark")
                                            .font(.caption)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(minHeight: 36)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 4)
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

    private func toggleSocialTag(_ tag: String) {
        if selectedSocialTags.contains(tag) {
            selectedSocialTags.remove(tag)
        } else {
            selectedSocialTags.insert(tag)
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
                skillLevel: skillLevel,
                socialTags: socialTagOptions.filter { selectedSocialTags.contains($0) }
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
                gender: .preferNotToSay,
                hostedEvents: [],
                participatedEvents: [],
                notifications: [],
                socialTags: ["intj", "software engineer"],
                createdAt: nil,
                updatedAt: nil
            )
        )
        .environmentObject(AppState())
    }
}
