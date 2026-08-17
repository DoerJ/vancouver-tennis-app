import Combine
import Foundation
import Supabase

@MainActor
final class AppState: ObservableObject {
    @Published var authenticationState: AuthenticationState = .signedOut
    @Published var googleSession: GoogleAuthSession?
    @Published var supabaseSession: Session?
    @Published var userProfile: UserProfile?
    @Published private(set) var contentLanguage = AppContent.currentLanguage
    @Published var eventsRevision = 0
    @Published private(set) var chatMessagesRevision = 0
    // Cached notifications are stored in memory to track read/unread state for the current user.
    @Published private(set) var cachedNotifications: [CachedNotificationState] = []
    @Published private(set) var cachedEventsByID: [UUID: TennisEvent] = [:]
    @Published private(set) var cachedChatMessagesByEventID: [UUID: [ChatRoomMessage]] = [:]

    private let profileService = ProfileService()
    private let eventService = EventService()
    private let chatMessageService = ChatMessageService()
    private let notificationEventService = NotificationEventService()
    private let deviceTokenService = DeviceTokenService()
    private let authService = SupabaseAuthService()
    private let realtimeSubscriptionManager = RealtimeSubscriptionManager()
    private var cancellables: Set<AnyCancellable> = []
    private var authStateChangesTask: Task<Void, Never>?
    private var activeChatEventID: UUID?
    private var lastSavedDeviceToken: String?
    private var isAwaitingDeletedAccountAcknowledgement = false

    init() {
        AppContent.setLanguage(contentLanguage)
        startAuthStateChangesListener()

        NotificationCenter.default.publisher(for: NotificationService.deviceTokenDidUpdateNotification)
            .compactMap { $0.object as? String }
            .sink { [weak self] deviceToken in
                Task {
                    await MainActor.run {
                        print(
                            "AppState: received APNs token update notification. tokenSuffix=\(deviceToken.suffix(8)), hasUserProfile=\(self?.userProfile != nil), userID=\(self?.userProfile?.id.uuidString ?? "nil")."
                        )
                    }
                    await self?.saveDeviceTokenIfPossible(deviceToken)
                }
            }
            .store(in: &cancellables)

    }

    func setContentLanguage(_ language: AppContent.Language) {
        guard contentLanguage != language else {
            return
        }

        AppContent.setLanguage(language)
        contentLanguage = language
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
            NotificationService.requestRemoteNotificationRegistration()
            await hydrateCachedNotificationReadState(currentUserID: session.user.id)
            await saveCurrentDeviceTokenIfPossible()
        } catch {
            forceLocalSignOut(reason: "AppState: failed to restore Supabase session: \(error.localizedDescription)")
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
            NotificationService.requestRemoteNotificationRegistration()
            await saveCurrentDeviceTokenIfPossible()
        }
    }

    func completeSignIn(
        supabaseSession: Session,
        userProfile: UserProfile
    ) {
        googleSession = nil
        applyAuthenticatedState(supabaseSession: supabaseSession, userProfile: userProfile)

        Task {
            NotificationService.requestRemoteNotificationRegistration()
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

    func isDisplayNameTaken(_ displayName: String) async throws -> Bool {
        guard let supabaseSession else {
            throw AppStateError.missingAuthenticatedUser
        }

        return try await profileService.isDisplayNameTaken(
            displayName,
            excluding: supabaseSession.user.id
        )
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

        try await eventService.cancelHostedEvent(event)

        if let updatedProfile = try await profileService.findProfile(userID: supabaseSession.user.id) {
            applyAuthenticatedState(supabaseSession: supabaseSession, userProfile: updatedProfile)
        }
        eventsRevision += 1
    }

    func refreshCurrentProfile() async {
        guard supabaseSession != nil,
              !isAwaitingDeletedAccountAcknowledgement
        else {
            return
        }

        let refreshedSession: Session

        do {
            refreshedSession = try await SupabaseClientProvider.shared.auth.session
        } catch {
            forceLocalSignOut(reason: "AppState: Supabase session refresh failed: \(error.localizedDescription)")
            return
        }

        do {
            if let profile = try await profileService.findProfile(userID: refreshedSession.user.id) {
                applyAuthenticatedState(supabaseSession: refreshedSession, userProfile: profile)
                await hydrateCachedNotificationReadState(currentUserID: refreshedSession.user.id)
            }
        } catch {
            print("AppState: failed to refresh current profile: \(error.localizedDescription)")
        }
    }

    func handleAppBecameActive() async {
        guard !isAwaitingDeletedAccountAcknowledgement else {
            return
        }

        await refreshCurrentProfile()
        guard authenticationState == .signedIn,
              let userID = userProfile?.id,
              supabaseSession != nil
        else {
            return
        }

        ensureProfileRealtimeSubscription(userID: userID)
    }

    func updateCachedNotifications(_ notificationIDs: [UUID]) {
        userProfile = userProfile?.updatingNotifications(notificationIDs)
        syncCachedNotifications(notificationIDs: notificationIDs)
    }

    func updateCachedNotifications(_ notifications: [NotificationEvent], currentUserID: UUID) {
        let notificationIDs = notifications.map(\.id)
        let readStateByID = notifications.reduce(into: [UUID: Bool]()) { states, notification in
            states[notification.id] = notification.isRead(by: currentUserID)
        }

        userProfile = userProfile?.updatingNotifications(notificationIDs)
        cachedNotifications = notificationIDs.map { notificationID in
            CachedNotificationState(
                id: notificationID,
                read: readStateByID[notificationID] ?? isCachedNotificationRead(notificationID)
            )
        }
    }

    func updateCachedEvents(hostedEvents: [UUID], participatedEvents: [UUID]) {
        userProfile = userProfile?.updatingEvents(
            hostedEvents: hostedEvents,
            participatedEvents: participatedEvents
        )
        // Temporarily disabled while debugging the profiles realtime subscription.
        // startChatMessagesRealtimeSubscriptions(eventIDs: Array(Set(hostedEvents + participatedEvents)))
    }

    func updateCachedAllEventsRead(_ isAllEventsRead: Bool) {
        userProfile = userProfile?.updatingAllEventsRead(isAllEventsRead)
    }

    func updateCachedAllNotificationsRead(_ isAllNotificationsRead: Bool) {
        userProfile = userProfile?.updatingAllNotificationsRead(isAllNotificationsRead)
    }

    func appendCachedPendingEvent(_ eventID: UUID) {
        guard let userProfile,
              !userProfile.pendingEvents.contains(eventID)
        else {
            return
        }

        self.userProfile = userProfile.updatingPendingEvents(userProfile.pendingEvents + [eventID])
    }

    func removeCachedPendingEvent(_ eventID: UUID) {
        guard let userProfile,
              userProfile.pendingEvents.contains(eventID)
        else {
            return
        }

        self.userProfile = userProfile.updatingPendingEvents(
            userProfile.pendingEvents.filter { $0 != eventID }
        )
    }

    func removeCachedEvent(_ eventID: UUID) {
        guard let userProfile else {
            return
        }

        cachedEventsByID[eventID] = nil
        cachedChatMessagesByEventID[eventID] = nil

        self.userProfile = userProfile
            .updatingEvents(
                hostedEvents: userProfile.hostedEvents.filter { $0 != eventID },
                participatedEvents: userProfile.participatedEvents.filter { $0 != eventID }
            )
            .removingChatMessageReadState(eventID: eventID)
    }

    func removeCachedNotification(_ notificationID: UUID) {
        guard let userProfile else {
            return
        }

        self.userProfile = userProfile.updatingNotifications(
            userProfile.notifications.filter { $0 != notificationID }
        )
        cachedNotifications.removeAll { $0.id == notificationID }
    }

    func markCachedNotificationRead(_ notificationID: UUID) {
        cachedNotifications = cachedNotifications.map { notification in
            guard notification.id == notificationID else {
                return notification
            }

            return CachedNotificationState(id: notification.id, read: true)
        }
    }

    func isCachedNotificationRead(_ notificationID: UUID) -> Bool {
        cachedNotifications.first { $0.id == notificationID }?.read ?? true
    }

    func cachedEvents(ids eventIDs: [UUID]) -> [TennisEvent] {
        eventIDs.compactMap { cachedEventsByID[$0] }
    }

    func missingCachedEventIDs(ids eventIDs: [UUID]) -> [UUID] {
        eventIDs.filter { cachedEventsByID[$0] == nil }
    }

    func updateCachedEvents(_ events: [TennisEvent]) {
        guard !events.isEmpty else {
            return
        }

        for event in events {
            cachedEventsByID[event.id] = event
        }

        eventsRevision += 1
    }

    func applyUpdatedEvent(_ event: TennisEvent) {
        cachedEventsByID[event.id] = event
        eventsRevision += 1
    }

    func activeEventsForCurrentUser() async throws -> [TennisEvent] {
        guard let userProfile else {
            throw AppStateError.missingAuthenticatedUser
        }

        let eventIDs = Array(Set(userProfile.hostedEvents + userProfile.participatedEvents + userProfile.pendingEvents))
        let cachedEvents = cachedEvents(ids: eventIDs)
        let missingEventIDs = missingCachedEventIDs(ids: eventIDs)
        let fetchedEvents = try await eventService.fetchEvents(ids: missingEventIDs)

        updateCachedEvents(fetchedEvents)

        let now = Date()
        return (cachedEvents + fetchedEvents)
            .filter { $0.endTime > now }
    }

    var hasUnreadChats: Bool {
        !unreadChatEventIDs.isEmpty
    }

    var hasUnreadMyEvents: Bool {
        userProfile?.isAllEventsRead == false
    }

    var hasUnreadNotifications: Bool {
        userProfile?.isAllNotificationsRead == false
    }

    func hasUnreadChatMessages(eventID: UUID) -> Bool {
        unreadChatEventIDs.contains(eventID)
    }

    func openChatList() {
        activeChatEventID = nil
        NotificationService.setActiveChatEventID(nil)

        realtimeSubscriptionManager.startSharedChatMessagesRealtimeSubscription { [weak self] chatMessage in
            self?.handleRealtimeChatMessage(chatMessage)
        }
    }

    func openChat(eventID: UUID) {
        print("ChatDebug: [AppState] openChat called. eventID=\(eventID), currentUserID=\(userProfile?.id.uuidString ?? "none"), activeChatEventID=\(activeChatEventID?.uuidString ?? "none").")
        activeChatEventID = eventID
        NotificationService.setActiveChatEventID(eventID)
        markCachedChatMessagesRead(eventID: eventID)
        realtimeSubscriptionManager.startChatMessagesRealtimeSubscription(eventID: eventID) { [weak self] chatMessage in
            print("ChatDebug: [AppState] realtime callback received. eventID=\(chatMessage.eventID), messageID=\(chatMessage.id), senderID=\(chatMessage.senderID).")
            self?.handleRealtimeChatMessage(chatMessage)
        }
    }

    func closeChat(eventID: UUID) {
        print("ChatDebug: [AppState] closeChat called. eventID=\(eventID), activeChatEventID=\(activeChatEventID?.uuidString ?? "none").")
        markCachedChatMessagesRead(eventID: eventID)

        if activeChatEventID == eventID {
            realtimeSubscriptionManager.stopChatMessagesRealtimeSubscription()
            activeChatEventID = nil
            NotificationService.setActiveChatEventID(nil)
        }
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
            print("ChatDebug: [AppState] cache merge skipped; no changes. eventID=\(eventID), incomingCount=\(messages.count), existingCount=\(existingMessages.count).")
            return
        }

        cachedChatMessagesByEventID[eventID] = mergedMessages
        chatMessagesRevision += 1
        print("ChatDebug: [AppState] cache merged messages. eventID=\(eventID), incomingCount=\(messages.count), existingCount=\(existingMessages.count), mergedCount=\(mergedMessages.count), revision=\(chatMessagesRevision).")
    }

    func appendCachedChatMessage(_ message: ChatRoomMessage, eventID: UUID) {
        var messages = cachedChatMessagesByEventID[eventID] ?? []

        guard !messages.contains(where: { $0.id == message.id }) else {
            print("ChatDebug: [AppState] cache append skipped; duplicate message. eventID=\(eventID), messageID=\(message.id), cachedCount=\(messages.count), revision=\(chatMessagesRevision).")
            return
        }

        messages.append(message)
        messages.sort { $0.sentAt < $1.sentAt }
        cachedChatMessagesByEventID[eventID] = messages
        chatMessagesRevision += 1
        print("ChatDebug: [AppState] cache appended message. eventID=\(eventID), messageID=\(message.id), senderID=\(message.senderID), cachedCount=\(messages.count), revision=\(chatMessagesRevision).")
    }

    private func markCachedChatMessagesRead(eventID: UUID) {
        userProfile = userProfile?.updatingChatMessageReadState(eventID: eventID, read: true)

        Task {
            do {
                try await profileService.markCurrentUserChatMessagesRead(eventID: eventID)
            } catch {
                print("AppState: failed to mark chat messages read: \(error.localizedDescription)")
            }
        }
    }

    func preloadCachedChatMessages(eventIDs: [UUID]) async {
        for eventID in eventIDs where cachedChatMessagesByEventID[eventID] == nil {
            await refreshCachedChatMessages(eventID: eventID)
        }
    }

    func refreshCachedChatMessages(eventIDs: [UUID]) async {
        for eventID in eventIDs {
            await refreshCachedChatMessages(eventID: eventID)
        }
    }

    func deleteAccountProfileDataAndRevokeSession() async throws {
        guard supabaseSession != nil else {
            throw AppStateError.missingAuthenticatedUser
        }

        isAwaitingDeletedAccountAcknowledgement = true

        do {
            realtimeSubscriptionManager.stopAll()
            try await profileService.deleteAccountProfileData()
            try await authService.signOut()
            NotificationService.setUserSignedIn(false)
        } catch {
            isAwaitingDeletedAccountAcknowledgement = false
            throw error
        }

        // Suppress foreground notifications after Supabase session is revoked
        NotificationService.unregisterRemoteNotifications()
        lastSavedDeviceToken = nil
        eventsRevision += 1
    }

    func finishDeletedAccountFlow() {
        isAwaitingDeletedAccountAcknowledgement = false
        realtimeSubscriptionManager.stopAll()
        NotificationService.setUserSignedIn(false)
        NotificationService.unregisterRemoteNotifications()
        lastSavedDeviceToken = nil
        googleSession = nil
        supabaseSession = nil
        userProfile = nil
        cachedNotifications = []
        cachedEventsByID = [:]
        cachedChatMessagesByEventID = [:]
        chatMessagesRevision += 1
        authenticationState = .signedOut
    }

    func signOut() async {
        realtimeSubscriptionManager.stopAll()

        do {
            try await authService.signOut()
        } catch {
            // Local auth state should still be cleared if remote sign-out fails.
        }

        forceLocalSignOut(reason: nil)
    }

    private func forceLocalSignOut(reason: String?) {
        if let reason {
            print(reason)
        }

        isAwaitingDeletedAccountAcknowledgement = false
        realtimeSubscriptionManager.stopAll()
        NotificationService.setUserSignedIn(false)
        NotificationService.unregisterRemoteNotifications()
        lastSavedDeviceToken = nil
        googleSession = nil
        supabaseSession = nil
        userProfile = nil
        cachedNotifications = []
        cachedEventsByID = [:]
        cachedChatMessagesByEventID = [:]
        chatMessagesRevision += 1
        authenticationState = .signedOut
    }

    // If Supabase session token is expired while app is still running, the user will be signed out and the app will return to the sign-in page.
    private func startAuthStateChangesListener() {
        authStateChangesTask = Task { [weak self] in
            for await state in SupabaseClientProvider.shared.auth.authStateChanges {
                guard state.event == .signedOut || state.event == .userDeleted else {
                    continue
                }

                await MainActor.run {
                    guard self?.isAwaitingDeletedAccountAcknowledgement != true else {
                        print("AppState: ignored \(state.event.rawValue) auth state while waiting for deleted-account acknowledgement.")
                        return
                    }

                    self?.forceLocalSignOut(
                        reason: "AppState: Supabase auth state changed to \(state.event.rawValue)."
                    )
                }
            }
        }
    }

    private func applyAuthenticatedState(supabaseSession: Session, userProfile: UserProfile) {
        let nextAuthenticationState: AuthenticationState = userProfile.skillLevel == nil || userProfile.gender == nil ? .needsSkillLevel : .signedIn

        print(
            "AppState: applying authenticated state. userID=\(userProfile.id), previousState=\(authenticationState), nextState=\(nextAuthenticationState), skillLevelSet=\(userProfile.skillLevel != nil), genderSet=\(userProfile.gender != nil)."
        )

        self.supabaseSession = supabaseSession
        applyProfileState(userProfile)
        NotificationService.setUserSignedIn(true)
        authenticationState = nextAuthenticationState

        if case .signedIn = nextAuthenticationState {
            ensureProfileRealtimeSubscription(userID: userProfile.id)
        }
    }

    private func ensureProfileRealtimeSubscription(userID: UUID) {
        realtimeSubscriptionManager.ensureProfileRealtimeSubscription(
            userID: userID,
            onProfileUpdate: { [weak self] updatedProfile in
                self?.applyRealtimeProfileUpdate(updatedProfile)
            },
            onSubscriptionRecovered: { [weak self] in
                await self?.refreshCurrentProfile()
            }
        )
    }

    private func applyRealtimeProfileUpdate(_ updatedProfile: UserProfile) {
        guard updatedProfile.id == userProfile?.id else {
            print("AppState: ignored realtime profile update for a different user.")
            return
        }

        let oldEventIDs = Set((userProfile?.hostedEvents ?? []) + (userProfile?.participatedEvents ?? []))
        let updatedEventIDs = Set(updatedProfile.hostedEvents + updatedProfile.participatedEvents)
        let addedEventIDs = updatedEventIDs.subtracting(oldEventIDs)

        print(
            "AppState: applying realtime profile update. userID=\(updatedProfile.id), isAllEventsRead=\(updatedProfile.isAllEventsRead), isAllNotificationsRead=\(updatedProfile.isAllNotificationsRead), unreadChatEventIDs=\(Array(unreadChatEventIDs(from: updatedProfile))), addedEventIDs=\(Array(addedEventIDs)), notificationCount=\(updatedProfile.notifications.count)."
        )
        applyProfileState(updatedProfile)
        print(
            "AppState: realtime profile update applied. hasUnreadChats=\(hasUnreadChats), hasUnreadMyEvents=\(hasUnreadMyEvents), hasUnreadNotifications=\(hasUnreadNotifications)."
        )
    }

    private func applyProfileState(_ profile: UserProfile) {
        userProfile = profile
        syncCachedNotifications(notificationIDs: profile.notifications)
        // Temporarily disabled while debugging the profiles realtime subscription.
        // startChatMessagesRealtimeSubscriptions(eventIDs: Array(Set(profile.hostedEvents + profile.participatedEvents)))
    }

    private var unreadChatEventIDs: Set<UUID> {
        guard let userProfile else {
            return []
        }

        return unreadChatEventIDs(from: userProfile)
    }

    private func unreadChatEventIDs(from profile: UserProfile) -> Set<UUID> {
        let chatEventIDs = Set(profile.hostedEvents + profile.participatedEvents)

        return Set(
            profile.chatMessageReadStates.compactMap { readState in
                guard chatEventIDs.contains(readState.id), !readState.read else {
                    return nil
                }

                return readState.id
            }
        )
    }

    private func syncCachedNotifications(notificationIDs: [UUID]) {
        let existingReadStateByID = cachedNotifications.reduce(into: [UUID: Bool]()) { states, notification in
            states[notification.id] = notification.read
        }

        cachedNotifications = notificationIDs.map { notificationID in
            CachedNotificationState(
                id: notificationID,
                read: existingReadStateByID[notificationID] ?? false
            )
        }
    }

    // To handle app process termination and restore the existing session
    // After restoring the existing session, the cached notification read state is hydrated from Supabase notifications table to ensure the read state is accurate for the current user.
    private func hydrateCachedNotificationReadState(currentUserID: UUID) async {
        let notificationIDs = userProfile?.notifications ?? []

        guard !notificationIDs.isEmpty else {
            cachedNotifications = []
            return
        }

        do {
            let notifications = try await notificationEventService.fetchNotifications(ids: notificationIDs)
            updateCachedNotifications(notifications, currentUserID: currentUserID)
        } catch {
            print("AppState: failed to hydrate notification read state: \(error.localizedDescription)")
        }
    }

    @discardableResult
    private func refreshCachedChatMessages(eventID: UUID) async -> [ChatRoomMessage] {
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
                    senderDisplayName: profilesByID[message.senderID]?.displayName ?? AppContent.string("chat.unknownPlayer"),
                    body: message.body,
                    sentAt: message.createdAt
                )
            }

            updateCachedChatMessages(messages, eventID: eventID)
            print("AppState: refreshed cached chat messages for event \(eventID).")
            return messages
        } catch {
            print("AppState: failed to refresh cached chat messages: \(error.localizedDescription)")
            return []
        }
    }

    private func chatRoomMessage(from chatMessage: ChatMessage) async throws -> ChatRoomMessage {
        let profiles = try await profileService.fetchProfiles(userIDs: [chatMessage.senderID])
        let displayName = profiles.first?.displayName ?? AppContent.string("chat.unknownPlayer")

        return ChatRoomMessage(
            id: chatMessage.id,
            senderID: chatMessage.senderID,
            senderDisplayName: displayName,
            body: chatMessage.body,
            sentAt: chatMessage.createdAt
        )
    }

    private func handleRealtimeChatMessage(_ chatMessage: ChatMessage) {
        print("ChatDebug: [AppState] handleRealtimeChatMessage started. eventID=\(chatMessage.eventID), messageID=\(chatMessage.id), senderID=\(chatMessage.senderID).")
        Task { [weak self] in
            do {
                let message = try await self?.chatRoomMessage(from: chatMessage)

                await MainActor.run {
                    if let message {
                        print("ChatDebug: [AppState] mapped realtime chat message. eventID=\(chatMessage.eventID), messageID=\(message.id), displayName=\(message.senderDisplayName).")
                        self?.appendCachedChatMessage(message, eventID: chatMessage.eventID)
                    } else {
                        print("ChatDebug: [AppState] realtime chat message mapping returned nil. eventID=\(chatMessage.eventID), messageID=\(chatMessage.id).")
                    }
                }
            } catch {
                print("ChatDebug: [AppState] failed to map realtime chat message. eventID=\(chatMessage.eventID), messageID=\(chatMessage.id), error=\(error.localizedDescription).")
            }
        }
    }

    private func saveCurrentDeviceTokenIfPossible() async {
        guard let deviceToken = NotificationService.currentDeviceToken else {
            print("AppState: no APNs device token available to save. hasUserProfile=\(userProfile != nil), userID=\(userProfile?.id.uuidString ?? "nil").")
            return
        }

        print("AppState: found current APNs device token to save. tokenSuffix=\(deviceToken.suffix(8)), userID=\(userProfile?.id.uuidString ?? "nil").")
        await saveDeviceTokenIfPossible(deviceToken)
    }

    private func saveDeviceTokenIfPossible(_ deviceToken: String) async {
        guard let userID = userProfile?.id else {
            print("AppState: device token received before user profile was available. tokenSuffix=\(deviceToken.suffix(8)).")
            return
        }

        guard lastSavedDeviceToken != deviceToken else {
            print("AppState: skipped APNs device token save because token is already saved in memory. userID=\(userID), tokenSuffix=\(deviceToken.suffix(8)).")
            return
        }

        do {
            print("AppState: saving APNs device token. userID=\(userID), tokenSuffix=\(deviceToken.suffix(8)).")
            try await deviceTokenService.saveDeviceToken(
                userID: userID,
                deviceToken: deviceToken
            )
            lastSavedDeviceToken = deviceToken
            print("AppState: saved APNs device token. userID=\(userID), tokenSuffix=\(deviceToken.suffix(8)).")
        } catch {
            print("AppState: failed to save APNs device token. userID=\(userID), tokenSuffix=\(deviceToken.suffix(8)), error=\(error.localizedDescription).")
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
            return AppContent.string("errors.noAuthenticatedUser")
        case .notEventHost:
            return AppContent.string("errors.onlyHostCanCancel")
        }
    }
}
