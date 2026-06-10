import Combine
import Foundation
import Supabase

@MainActor
final class AppState: ObservableObject {
    @Published var authenticationState: AuthenticationState = .signedOut
    @Published var googleSession: GoogleAuthSession?
    @Published var supabaseSession: Session?
    @Published var userProfile: UserProfile?
    @Published var eventsRevision = 0

    private let profileService = ProfileService()
    private let eventService = EventService()
    private let deviceTokenService = DeviceTokenService()
    private let authService = SupabaseAuthService()
    private var cancellables: Set<AnyCancellable> = []
    private var lastSavedDeviceToken: String?

    init() {
        NotificationCenter.default.publisher(for: NotificationService.deviceTokenDidUpdateNotification)
            .compactMap { $0.object as? String }
            .sink { [weak self] deviceToken in
                Task {
                    await self?.saveDeviceTokenIfPossible(deviceToken)
                }
            }
            .store(in: &cancellables)
    }

    func restoreExistingSession() async {
        guard AppConfig.isSupabaseConfigured else {
            authenticationState = .signedOut
            return
        }

        do {
            let session = try await SupabaseClientProvider.shared.auth.session
            let profile = try await profileService.findOrCreateProfile(for: session.user)

            applyAuthenticatedState(supabaseSession: session, userProfile: profile)
            await saveCurrentDeviceTokenIfPossible()
        } catch {
            supabaseSession = nil
            userProfile = nil
            authenticationState = .signedOut
        }
    }

    func completeSignIn(
        googleSession: GoogleAuthSession,
        supabaseSession: Session,
        userProfile: UserProfile
    ) {
        self.googleSession = googleSession
        applyAuthenticatedState(supabaseSession: supabaseSession, userProfile: userProfile)

        Task {
            await saveCurrentDeviceTokenIfPossible()
        }
    }

    func updateProfile(
        displayName: String? = nil,
        skillLevel: SkillLevel? = nil,
        gender: Gender? = nil
    ) async throws {
        guard let supabaseSession else {
            throw AppStateError.missingAuthenticatedUser
        }

        guard displayName != nil || skillLevel != nil || gender != nil else {
            return
        }

        let updatedProfile = try await profileService.updateProfile(
            userID: supabaseSession.user.id,
            displayName: displayName,
            skillLevel: skillLevel,
            gender: gender
        )

        applyAuthenticatedState(supabaseSession: supabaseSession, userProfile: updatedProfile)
    }

    func appendHostedEvent(_ eventID: UUID) async throws {
        guard let supabaseSession else {
            throw AppStateError.missingAuthenticatedUser
        }

        let updatedProfile = try await profileService.appendHostedEvent(
            userID: supabaseSession.user.id,
            eventID: eventID
        )

        applyAuthenticatedState(supabaseSession: supabaseSession, userProfile: updatedProfile)
        eventsRevision += 1
    }

    func cancelHostedEvent(_ event: TennisEvent) async throws {
        guard let supabaseSession else {
            throw AppStateError.missingAuthenticatedUser
        }

        guard event.hostID == supabaseSession.user.id else {
            throw AppStateError.notEventHost
        }

        try await eventService.deleteEvent(
            eventID: event.id,
            hostID: supabaseSession.user.id
        )

        let updatedProfile = try await profileService.removeHostedEvent(
            userID: supabaseSession.user.id,
            eventID: event.id
        )

        applyAuthenticatedState(supabaseSession: supabaseSession, userProfile: updatedProfile)
        eventsRevision += 1
    }

    func signOut() async {
        do {
            try await authService.signOut()
        } catch {
            // Local auth state should still be cleared if remote sign-out fails.
        }

        googleSession = nil
        supabaseSession = nil
        userProfile = nil
        authenticationState = .signedOut
    }

    private func applyAuthenticatedState(supabaseSession: Session, userProfile: UserProfile) {
        self.supabaseSession = supabaseSession
        self.userProfile = userProfile
        authenticationState = userProfile.skillLevel == nil || userProfile.gender == nil ? .needsSkillLevel : .signedIn
    }

    private func saveCurrentDeviceTokenIfPossible() async {
        guard let deviceToken = NotificationService.currentDeviceToken else {
            print("AppState: no APNs device token available to save.")
            return
        }

        await saveDeviceTokenIfPossible(deviceToken)
    }

    private func saveDeviceTokenIfPossible(_ deviceToken: String) async {
        guard let userID = userProfile?.id else {
            print("AppState: device token received before user profile was available.")
            return
        }

        guard lastSavedDeviceToken != deviceToken else {
            return
        }

        do {
            try await deviceTokenService.saveDeviceToken(
                userID: userID,
                deviceToken: deviceToken
            )
            lastSavedDeviceToken = deviceToken
            print("AppState: saved APNs device token.")
        } catch {
            print("AppState: failed to save APNs device token: \(error.localizedDescription)")
        }
    }
}

enum AuthenticationState {
    case signedOut
    case signingIn
    case needsSkillLevel
    case signedIn
}

enum AppStateError: LocalizedError {
    case missingAuthenticatedUser
    case notEventHost

    var errorDescription: String? {
        switch self {
        case .missingAuthenticatedUser:
            return "No authenticated user was found."
        case .notEventHost:
            return "Only the host can cancel this event."
        }
    }
}
