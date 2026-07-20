import Combine
import Foundation

@MainActor
final class OnboardingProfileViewModel: ObservableObject {
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?

    func saveProfile(
        selectedLevel: SkillLevel?,
        selectedGender: Gender?,
        selectedSocialTags: Set<String>,
        appState: AppState
    ) async {
        guard !isSaving else {
            return
        }

        guard let selectedLevel, let selectedGender else {
            return
        }

        isSaving = true
        errorMessage = nil
        defer {
            isSaving = false
        }

        do {
            try await appState.updateProfile(
                skillLevel: selectedLevel,
                gender: selectedGender,
                socialTags: Constants.SocialProfile.tagOptions.filter { selectedSocialTags.contains($0) }
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
