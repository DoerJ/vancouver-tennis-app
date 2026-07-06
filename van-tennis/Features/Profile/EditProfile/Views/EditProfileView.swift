import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    private let originalDisplayName: String
    private let originalSkillLevel: SkillLevel
    private let originalSocialTags: Set<String>

    @State private var displayName: String
    @State private var skillLevel: SkillLevel
    @State private var selectedSocialTags: Set<String>
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(profile: UserProfile) {
        originalDisplayName = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        originalSkillLevel = profile.skillLevel ?? .one
        originalSocialTags = Set(profile.socialTags)
        _displayName = State(initialValue: profile.displayName)
        _skillLevel = State(initialValue: originalSkillLevel)
        _selectedSocialTags = State(initialValue: originalSocialTags)
    }

    var body: some View {
        Form {
            Section(AppContent.string("profile.title")) {
                TextField(AppContent.string("profile.displayName"), text: $displayName)
                    .textInputAutocapitalization(.words)

                Picker(AppContent.string("profile.skillLevel"), selection: $skillLevel) {
                    ForEach(SkillLevel.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
            }

            Section(AppContent.string("auth.onboarding.socialTags")) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Constants.SocialProfile.tagOptions, id: \.self) { tag in
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
        .navigationTitle(AppContent.string("profile.editTitle"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSaving ? AppContent.string("common.saving") : AppContent.string("common.save")) {
                    Task {
                        await save()
                    }
                }
                .disabled(isSaving || !hasProfileChanges || trimmedDisplayName.isEmpty)
            }
        }
    }

    private var trimmedDisplayName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasProfileChanges: Bool {
        trimmedDisplayName != originalDisplayName
            || skillLevel != originalSkillLevel
            || selectedSocialTags != originalSocialTags
    }

    private func toggleSocialTag(_ tag: String) {
        if selectedSocialTags.contains(tag) {
            selectedSocialTags.remove(tag)
        } else {
            selectedSocialTags.insert(tag)
        }
    }

    private func save() async {
        guard !trimmedDisplayName.isEmpty else {
            errorMessage = AppContent.string("profile.displayNameRequired")
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            if trimmedDisplayName != originalDisplayName,
               try await appState.isDisplayNameTaken(trimmedDisplayName) {
                errorMessage = AppContent.string("profile.displayNameTaken")
                isSaving = false
                return
            }

            try await appState.updateProfile(
                displayName: trimmedDisplayName,
                skillLevel: skillLevel,
                socialTags: Constants.SocialProfile.tagOptions.filter { selectedSocialTags.contains($0) }
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
