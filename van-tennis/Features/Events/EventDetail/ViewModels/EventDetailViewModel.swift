import Combine
import Foundation

@MainActor
final class EventDetailViewModel: ObservableObject {
    @Published var hostProfile: UserProfile?
    @Published var participantProfiles: [UserProfile] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let profileService = ProfileService()

    func loadDetails(for event: TennisEvent) async {
        isLoading = true
        errorMessage = nil

        do {
            hostProfile = try await profileService.findProfile(userID: event.hostID)

            participantProfiles = try await profileService
                .fetchProfiles(userIDs: event.participants)
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
