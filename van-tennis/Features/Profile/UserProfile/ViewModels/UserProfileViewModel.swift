import Foundation
import Combine

@MainActor
final class UserProfileViewModel: ObservableObject {
    @Published var isShowingAccountDeletedAlert = false
    @Published var editedDisplayName = ""
    @Published private(set) var isEditingDisplayName = false
    @Published private(set) var isSavingDisplayName = false
    @Published private(set) var displayNameErrorMessage: String?
    @Published private(set) var isDeletingAccount = false
    @Published private(set) var deleteAccountErrorMessage: String?

    func startDisplayNameEditing(profile: UserProfile?) {
        guard let profile else {
            return
        }

        editedDisplayName = profile.displayName
        displayNameErrorMessage = nil
        isEditingDisplayName = true
    }

    func syncDisplayNameIfNeeded(_ displayName: String?) {
        guard !isEditingDisplayName else {
            return
        }

        editedDisplayName = displayName ?? ""
    }

    func canSaveDisplayName(currentDisplayName: String?) -> Bool {
        isEditingDisplayName
            && !trimmedDisplayName(editedDisplayName).isEmpty
            && trimmedDisplayName(editedDisplayName) != currentDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func clearDisplayNameError() {
        displayNameErrorMessage = nil
    }

    func saveDisplayName(
        currentDisplayName: String?,
        appState: AppState
    ) async -> Bool {
        guard isEditingDisplayName else {
            return false
        }

        let trimmedDisplayName = trimmedDisplayName(editedDisplayName)

        guard !trimmedDisplayName.isEmpty else {
            displayNameErrorMessage = AppContent.string("profile.displayNameRequired")
            return false
        }

        guard trimmedDisplayName != currentDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            displayNameErrorMessage = nil
            isEditingDisplayName = false
            return true
        }

        isSavingDisplayName = true
        displayNameErrorMessage = nil

        defer {
            isSavingDisplayName = false
        }

        do {
            if try await appState.isDisplayNameTaken(trimmedDisplayName) {
                displayNameErrorMessage = AppContent.string("profile.displayNameTaken")
                return false
            }

            try await appState.updateProfile(displayName: trimmedDisplayName)
            isEditingDisplayName = false
            return true
        } catch {
            displayNameErrorMessage = error.localizedDescription
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
}
