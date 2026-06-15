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
    @Published private(set) var chatMessagesRevision = 0
    @Published private(set) var cachedChatMessagesByEventID: [UUID: [ChatRoomMessage]] = [:]

    private let profileService = ProfileService()
    private let eventService = EventService()
    private let chatMessageService = ChatMessageService()
    private let deviceTokenService = DeviceTokenService()
    private let authService = SupabaseAuthService()
    private var cancellables: Set<AnyCancellable> = []
    private var chatMessagesRealtimeTask: Task<Void, Never>?
    private var chatMessagesRealtimeChannel: RealtimeChannelV2?
    private var subscribedChatEventID: UUID?
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

        NotificationCenter.default.publisher(for: NotificationService.remoteNotificationDidArriveNotification)
            .sink { [weak self] _ in
                Task {
                    // Refresh the current user profile when a remote notification arrives
                    await self?.refreshCurrentProfile()
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

    func cachedChatMessages(eventID: UUID) -> [ChatRoomMessage]? {
        cachedChatMessagesByEventID[eventID]
    }

    func updateCachedChatMessages(_ messages: [ChatRoomMessage], eventID: UUID) {
        let existingMessages = cachedChatMessagesByEventID[eventID] ?? []
        let mergedMessages = (existingMessages + messages)
            .reduce(into: [UUID: ChatRoomMessage]()) { messagesByID, message in
                messagesByID[message.id] = message
            }
            .values
            .sorted { $0.sentAt < $1.sentAt }

        guard cachedChatMessagesByEventID[eventID] != mergedMessages else {
            return
        }

        cachedChatMessagesByEventID[eventID] = mergedMessages
        chatMessagesRevision += 1
    }

    func appendCachedChatMessage(_ message: ChatRoomMessage, eventID: UUID) {
        var messages = cachedChatMessagesByEventID[eventID] ?? []

        guard !messages.contains(where: { $0.id == message.id }) else {
            return
        }

        messages.append(message)
        messages.sort { $0.sentAt < $1.sentAt }
        cachedChatMessagesByEventID[eventID] = messages
        chatMessagesRevision += 1
    }

    func startChatMessagesRealtimeSubscription(eventID: UUID) {
        // Subscribe to Supabase Realtime channel for listening to new row insertion of chat_messages table
        guard subscribedChatEventID != eventID else {
            return
        }

        stopChatMessagesRealtimeSubscription()
        subscribedChatEventID = eventID

        let client = SupabaseClientProvider.shared
        let channel = client.realtimeV2.channel("chat-messages-\(eventID.uuidString)")
        chatMessagesRealtimeChannel = channel

        chatMessagesRealtimeTask = Task { [weak self] in
            let inserts = channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "chat_messages",
                filter: .eq("event_id", value: eventID.uuidString)
            )

            do {
                await client.realtimeV2.setAuth()
                await client.realtimeV2.connect()
                try await channel.subscribeWithError()
                print("AppState: subscribed to realtime chat messages for event \(eventID).")

                for await _ in inserts {
                    guard !Task.isCancelled else {
                        break
                    }

                    await self?.refreshCachedChatMessages(eventID: eventID)
                }
            } catch is CancellationError {
                // Expected when leaving the chat room or switching events.
            } catch {
                print("AppState: chat messages realtime subscription failed: \(error.localizedDescription)")
            }
        }
    }

    func stopChatMessagesRealtimeSubscription() {
        chatMessagesRealtimeTask?.cancel()
        chatMessagesRealtimeTask = nil
        subscribedChatEventID = nil

        guard let chatMessagesRealtimeChannel else {
            return
        }

        self.chatMessagesRealtimeChannel = nil

        Task {
            await SupabaseClientProvider.shared.realtimeV2.removeChannel(chatMessagesRealtimeChannel)
        }
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
        stopChatMessagesRealtimeSubscription()
        googleSession = nil
        supabaseSession = nil
        userProfile = nil
        cachedChatMessagesByEventID = [:]
        chatMessagesRevision += 1
        authenticationState = .signedOut
    }

    func signOut() async {
        stopChatMessagesRealtimeSubscription()

        do {
            try await authService.signOut()
        } catch {
            // Local auth state should still be cleared if remote sign-out fails.
        }

        googleSession = nil
        supabaseSession = nil
        userProfile = nil
        cachedChatMessagesByEventID = [:]
        chatMessagesRevision += 1
        authenticationState = .signedOut
    }

    private func applyAuthenticatedState(supabaseSession: Session, userProfile: UserProfile) {
        self.supabaseSession = supabaseSession
        self.userProfile = userProfile
        authenticationState = userProfile.skillLevel == nil || userProfile.gender == nil ? .needsSkillLevel : .signedIn
    }

    private func refreshCachedChatMessages(eventID: UUID) async {
        // Refresh cached chat messages so chat page can be re-rendered with the new message
        do {
            let chatMessages = try await chatMessageService.fetchMessages(eventID: eventID)
            let senderIDs = Array(Set(chatMessages.map(\.senderID)))
            let profilesByID = try await profileService.fetchProfiles(userIDs: senderIDs)
                .reduce(into: [UUID: UserProfile]()) { profiles, profile in
                    profiles[profile.id] = profile
                }
            let messages = chatMessages.map { message in
                ChatRoomMessage(
                    id: message.id,
                    senderID: message.senderID,
                    senderDisplayName: profilesByID[message.senderID]?.displayName ?? "Unknown Player",
                    body: message.body,
                    sentAt: message.createdAt
                )
            }

            updateCachedChatMessages(messages, eventID: eventID)
            print("AppState: refreshed cached chat messages for event \(eventID).")
        } catch {
            print("AppState: failed to refresh cached chat messages: \(error.localizedDescription)")
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
