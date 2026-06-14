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
    private var profileRealtimeTask: Task<Void, Never>?
    private var profileRealtimeChannel: RealtimeChannelV2?
    private var subscribedProfileID: UUID?
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
        gender: Gender? = nil,
        socialTags: [String]? = nil
    ) async throws {
        guard let supabaseSession else {
            throw AppStateError.missingAuthenticatedUser
        }

        guard displayName != nil || skillLevel != nil || gender != nil || socialTags != nil else {
            return
        }

        let updatedProfile = try await profileService.updateProfile(
            userID: supabaseSession.user.id,
            displayName: displayName,
            skillLevel: skillLevel,
            gender: gender,
            socialTags: socialTags
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

        try await eventService.cancelHostedEvent(eventID: event.id)

        if let updatedProfile = try await profileService.findProfile(userID: supabaseSession.user.id) {
            applyAuthenticatedState(supabaseSession: supabaseSession, userProfile: updatedProfile)
        }
        eventsRevision += 1
    }

    func refreshCurrentProfile() async {
        guard let supabaseSession else {
            return
        }

        do {
            if let profile = try await profileService.findProfile(userID: supabaseSession.user.id) {
                applyAuthenticatedState(supabaseSession: supabaseSession, userProfile: profile)
            }
        } catch {
            print("AppState: failed to refresh current profile: \(error.localizedDescription)")
        }
    }

    func updateCachedNotifications(_ notificationIDs: [UUID]) {
        userProfile = userProfile?.updatingNotifications(notificationIDs)
    }

    func updateCachedEvents(hostedEvents: [UUID], participatedEvents: [UUID]) {
        userProfile = userProfile?.updatingEvents(
            hostedEvents: hostedEvents,
            participatedEvents: participatedEvents
        )
    }

    func removeCachedEvent(_ eventID: UUID) {
        guard let userProfile else {
            return
        }

        self.userProfile = userProfile.updatingEvents(
            hostedEvents: userProfile.hostedEvents.filter { $0 != eventID },
            participatedEvents: userProfile.participatedEvents.filter { $0 != eventID }
        )
    }

    func removeCachedNotification(_ notificationID: UUID) {
        guard let userProfile else {
            return
        }

        self.userProfile = userProfile.updatingNotifications(
            userProfile.notifications.filter { $0 != notificationID }
        )
    }

    func deleteAccountProfileDataAndRevokeSession() async throws {
        guard supabaseSession != nil else {
            throw AppStateError.missingAuthenticatedUser
        }

        try await profileService.deleteAccountProfileData()
        try await authService.signOut()
        eventsRevision += 1
    }

    func finishDeletedAccountFlow() {
        stopProfileRealtimeSubscription()
        googleSession = nil
        supabaseSession = nil
        userProfile = nil
        authenticationState = .signedOut
    }

    func signOut() async {
        stopProfileRealtimeSubscription()

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
        startProfileRealtimeSubscription(userID: userProfile.id)
    }

    private func startProfileRealtimeSubscription(userID: UUID) {
        /*
            Subscribe to Supabase realtime for current user's profiles table row,
            and update cached notifications whenever the profile row is updated
        */
        guard subscribedProfileID != userID else {
            return
        }

        stopProfileRealtimeSubscription()
        subscribedProfileID = userID

        let client = SupabaseClientProvider.shared
        let channel = client.realtimeV2.channel("profile-\(userID.uuidString)")
        profileRealtimeChannel = channel

        profileRealtimeTask = Task { [weak self] in
            let updates = channel.postgresChange(
                UpdateAction.self,
                schema: "public",
                table: "profiles",
                filter: .eq("id", value: userID.uuidString)
            )

            do {
                await client.realtimeV2.connect()
                try await channel.subscribeWithError()

                for await update in updates {
                    guard !Task.isCancelled else {
                        break
                    }

                    do {
                        let updatedProfile = try update.decodeRecord(
                            as: UserProfile.self,
                            decoder: Self.supabaseRealtimeDecoder
                        )

                        await MainActor.run {
                            self?.updateCachedNotifications(updatedProfile.notifications)
                        }
                    } catch {
                        print("AppState: failed to decode realtime profile update: \(error.localizedDescription)")
                        await self?.refreshCurrentProfile()
                    }
                }
            } catch is CancellationError {
                // Expected when signing out or switching users.
            } catch {
                print("AppState: profile realtime subscription failed: \(error.localizedDescription)")
            }
        }
    }

    private func stopProfileRealtimeSubscription() {
        profileRealtimeTask?.cancel()
        profileRealtimeTask = nil
        subscribedProfileID = nil

        guard let profileRealtimeChannel else {
            return
        }

        self.profileRealtimeChannel = nil

        Task {
            await SupabaseClientProvider.shared.realtimeV2.removeChannel(profileRealtimeChannel)
        }
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

    private static let supabaseRealtimeDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            if let date = fractionalFormatter.date(from: dateString) {
                return date
            }

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]

            if let date = formatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid Supabase date: \(dateString)"
            )
        }
        return decoder
    }()
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
