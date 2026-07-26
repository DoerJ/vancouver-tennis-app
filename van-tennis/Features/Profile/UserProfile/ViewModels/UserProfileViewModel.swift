import Foundation
import Combine

@MainActor
final class UserProfileViewModel: ObservableObject {
    @Published var isShowingAccountDeletedAlert = false
    @Published var editedDisplayName = ""
    @Published private(set) var selectedSkillLevel: SkillLevel?
    @Published private(set) var selectedGender: Gender?
    @Published private(set) var selectedSocialTags: Set<String> = []
    @Published private(set) var showsSocialTagOptions = false
    @Published private(set) var isEditingDisplayName = false
    @Published private(set) var isSavingProfile = false
    @Published private(set) var displayNameErrorMessage: String?
    @Published private(set) var skillLevelErrorMessage: String?
    @Published private(set) var socialTagsErrorMessage: String?
    @Published private(set) var isDeletingAccount = false
    @Published private(set) var deleteAccountErrorMessage: String?
    private var hasLoadedSocialTags = false

    func startDisplayNameEditing(profile: UserProfile?) {
        guard let profile else {
            return
        }

        editedDisplayName = profile.displayName
        displayNameErrorMessage = nil
        isEditingDisplayName = true
    }

    func syncProfileIfNeeded(_ profile: UserProfile?) {
        if !isEditingDisplayName {
            editedDisplayName = profile?.displayName ?? ""
        }

        if selectedSkillLevel == nil {
            selectedSkillLevel = profile?.skillLevel
        }

        if selectedGender == nil {
            selectedGender = profile?.gender
        }

        if !hasLoadedSocialTags {
            selectedSocialTags = Set(profile?.socialTags ?? [])
            hasLoadedSocialTags = true
        }
    }

    func selectSkillLevel(_ skillLevel: SkillLevel) {
        selectedSkillLevel = skillLevel
        skillLevelErrorMessage = nil
    }

    func selectGender(_ gender: Gender) {
        selectedGender = gender
    }

    func toggleSocialTagOptions() {
        showsSocialTagOptions.toggle()
    }

    func toggleSocialTag(_ tag: String) {
        if selectedSocialTags.contains(tag) {
            selectedSocialTags.remove(tag)
            socialTagsErrorMessage = nil
        } else if selectedSocialTags.count >= Constants.SocialProfile.maximumSelectedTags {
            socialTagsErrorMessage = AppContent.string(
                "profile.socialTagsLimit",
                Constants.SocialProfile.maximumSelectedTags
            )
        } else {
            selectedSocialTags.insert(tag)
            socialTagsErrorMessage = nil
        }
    }

    func canSaveProfile(currentProfile: UserProfile?) -> Bool {
        guard let currentProfile else {
            return false
        }

        guard !isEditingDisplayName || !trimmedDisplayName(editedDisplayName).isEmpty else {
            return false
        }

        return hasDisplayNameChange(currentDisplayName: currentProfile.displayName)
            || hasSkillLevelChange(currentSkillLevel: currentProfile.skillLevel)
            || hasGenderChange(currentGender: currentProfile.gender)
            || hasSocialTagsChange(currentSocialTags: currentProfile.socialTags)
    }

    func clearDisplayNameError() {
        displayNameErrorMessage = nil
    }

    func saveProfileChanges(
        currentProfile: UserProfile?,
        appState: AppState
    ) async -> Bool {
        guard let currentProfile else {
            return false
        }

        let trimmedDisplayName = trimmedDisplayName(editedDisplayName)

        if isEditingDisplayName && trimmedDisplayName.isEmpty {
            displayNameErrorMessage = AppContent.string("profile.displayNameRequired")
            return false
        }

        guard selectedSocialTags.count <= Constants.SocialProfile.maximumSelectedTags else {
            socialTagsErrorMessage = AppContent.string(
                "profile.socialTagsLimit",
                Constants.SocialProfile.maximumSelectedTags
            )
            return false
        }

        let shouldUpdateDisplayName = hasDisplayNameChange(currentDisplayName: currentProfile.displayName)
        let shouldUpdateSkillLevel = hasSkillLevelChange(currentSkillLevel: currentProfile.skillLevel)
        let shouldUpdateGender = hasGenderChange(currentGender: currentProfile.gender)
        let shouldUpdateSocialTags = hasSocialTagsChange(currentSocialTags: currentProfile.socialTags)

        guard shouldUpdateDisplayName || shouldUpdateSkillLevel || shouldUpdateGender || shouldUpdateSocialTags else {
            displayNameErrorMessage = nil
            skillLevelErrorMessage = nil
            isEditingDisplayName = false
            return true
        }

        isSavingProfile = true
        displayNameErrorMessage = nil
        skillLevelErrorMessage = nil
        socialTagsErrorMessage = nil

        defer {
            isSavingProfile = false
        }

        do {
            if shouldUpdateDisplayName,
               try await appState.isDisplayNameTaken(trimmedDisplayName) {
                displayNameErrorMessage = AppContent.string("profile.displayNameTaken")
                return false
            }

            try await appState.updateProfile(
                displayName: shouldUpdateDisplayName ? trimmedDisplayName : nil,
                skillLevel: shouldUpdateSkillLevel ? selectedSkillLevel : nil,
                gender: shouldUpdateGender ? selectedGender : nil,
                socialTags: shouldUpdateSocialTags ? sortedSelectedSocialTags : nil
            )
            isEditingDisplayName = false
            showsSocialTagOptions = false
            return true
        } catch {
            skillLevelErrorMessage = error.localizedDescription
            return false
        }
    }

    func deleteAccount(appState: AppState) async {
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

    private func trimmedDisplayName(_ displayName: String) -> String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func hasDisplayNameChange(currentDisplayName: String) -> Bool {
        isEditingDisplayName
            && !trimmedDisplayName(editedDisplayName).isEmpty
            && trimmedDisplayName(editedDisplayName) != currentDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func hasSkillLevelChange(currentSkillLevel: SkillLevel?) -> Bool {
        guard let selectedSkillLevel else {
            return false
        }

        return selectedSkillLevel != currentSkillLevel
    }

    private func hasGenderChange(currentGender: Gender?) -> Bool {
        guard let selectedGender else {
            return false
        }

        return selectedGender != currentGender
    }

    private var sortedSelectedSocialTags: [String] {
        Constants.SocialProfile.tagOptions.filter { selectedSocialTags.contains($0) }
    }

    private func hasSocialTagsChange(currentSocialTags: [String]) -> Bool {
        Set(currentSocialTags) != selectedSocialTags
    }
}
