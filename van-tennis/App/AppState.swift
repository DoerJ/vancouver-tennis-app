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
    @Published private(set) var unreadChatCountsByEventID: [UUID: Int] = [:]
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
    private var cancellables: Set<AnyCancellable> = []
    private var authStateChangesTask: Task<Void, Never>?
    private var chatMessagesRealtimeTask: Task<Void, Never>?
    private var chatMessagesRealtimeChannel: RealtimeChannelV2?
    private var subscribedChatEventIDs: Set<UUID> = []
    private var activeChatEventID: UUID?
    private var countedUnreadChatMessageIDsByEventID: [UUID: Set<UUID>] = [:]
    private var lastSavedDeviceToken: String?
    private static let supabaseRealtimeDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            if let date = AppState.iso8601DateFormatter.date(from: dateString) {
                return date
            }

            if let date = AppState.iso8601DateFormatterWithoutFractionalSeconds.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: \(dateString)"
            )
        }
        return decoder
    }()
    private static let iso8601DateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let iso8601DateFormatterWithoutFractionalSeconds = ISO8601DateFormatter()

    init() {
        unreadChatCountsByEventID = Self.loadUnreadChatCounts()
        startAuthStateChangesListener()

        NotificationCenter.default.publisher(for: NotificationService.deviceTokenDidUpdateNotification)
            .compactMap { $0.object as? String }
            .sink { [weak self] deviceToken in
                Task {
                    await self?.saveDeviceTokenIfPossible(deviceToken)
                }
            }
            .store(in: &cancellables)

        // Listen for remote notifications to refresh the current in-memory cached user profile
        NotificationCenter.default.publisher(for: NotificationService.remoteNotificationDidArriveNotification)
            .sink { [weak self] notification in
                let context = notification.object as? NotificationService.RemoteNotificationContext
                Task {
                    await self?.handleRemoteNotificationArrival(context)
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
        guard supabaseSession != nil else {
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
        pruneUnreadChatCounts(validEventIDs: Set(hostedEvents + participatedEvents))
        startChatMessagesRealtimeSubscriptions(eventIDs: Array(Set(hostedEvents + participatedEvents)))
    }

    func updateCachedAllEventsRead(_ isAllEventsRead: Bool) {
        userProfile = userProfile?.updatingAllEventsRead(isAllEventsRead)
    }

    func removeCachedEvent(_ eventID: UUID) {
        guard let userProfile else {
            return
        }

        cachedEventsByID[eventID] = nil
        cachedChatMessagesByEventID[eventID] = nil
        subscribedChatEventIDs.remove(eventID)
        clearUnreadChatCount(eventID: eventID)

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

    func activeHostedEventsForCurrentUser() async throws -> [TennisEvent] {
        guard let userProfile else {
            throw AppStateError.missingAuthenticatedUser
        }

        // If the hosted event has already been cached, read from cache
        // Otherwise, the missing hosted events will be fetched from Supabase
        let hostedEventIDs = userProfile.hostedEvents
        let cachedEvents = cachedEvents(ids: hostedEventIDs)
        let missingEventIDs = missingCachedEventIDs(ids: hostedEventIDs)
        let fetchedEvents = try await eventService.fetchEvents(ids: missingEventIDs)

        updateCachedEvents(fetchedEvents)

        let now = Date()
        return (cachedEvents + fetchedEvents)
            .filter { $0.endTime > now }
    }

    var hasUnreadChats: Bool {
        guard let userProfile else {
            return false
        }

        let chatEventIDs = Set(userProfile.hostedEvents + userProfile.participatedEvents)
        return unreadChatCountsByEventID.contains { eventID, count in
            chatEventIDs.contains(eventID) && count > 0
        }
    }

    // Returns true if there is false value of read state in cachedNotifications
    var hasUnreadNotifications: Bool {
        cachedNotifications.contains { !$0.read }
    }

    func unreadChatCount(eventID: UUID) -> Int {
        unreadChatCountsByEventID[eventID] ?? 0
    }

    func openChat(eventID: UUID) {
        activeChatEventID = eventID
        NotificationService.setActiveChatEventID(eventID)
        clearUnreadChatCount(eventID: eventID)
        markCachedChatMessagesRead(eventID: eventID)
        startChatMessagesRealtimeSubscription(eventID: eventID)
    }

    func closeChat(eventID: UUID) {
        if activeChatEventID == eventID {
            activeChatEventID = nil
            NotificationService.setActiveChatEventID(nil)
        }
    }

    private func isSubscribedChatEvent(_ eventID: UUID) -> Bool {
        subscribedChatEventIDs.contains(eventID)
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

    private func incrementUnreadChatCount(eventID: UUID) {
        unreadChatCountsByEventID[eventID, default: 0] += 1
        persistUnreadChatCounts()
    }

    private func clearUnreadChatCount(eventID: UUID) {
        guard unreadChatCountsByEventID[eventID] != nil else {
            countedUnreadChatMessageIDsByEventID[eventID] = nil
            return
        }

        unreadChatCountsByEventID[eventID] = nil
        countedUnreadChatMessageIDsByEventID[eventID] = nil
        persistUnreadChatCounts()
    }

    private func pruneUnreadChatCounts(validEventIDs: Set<UUID>) {
        let prunedCounts = unreadChatCountsByEventID.filter { eventID, count in
            validEventIDs.contains(eventID) && count > 0
        }

        guard prunedCounts != unreadChatCountsByEventID else {
            return
        }

        unreadChatCountsByEventID = prunedCounts
        countedUnreadChatMessageIDsByEventID = countedUnreadChatMessageIDsByEventID.filter { eventID, _ in
            validEventIDs.contains(eventID)
        }
        persistUnreadChatCounts()
    }

    private func recordIncomingRealtimeChatMessage(_ message: ChatRoomMessage, eventID: UUID) {
        recordIncomingChatMessage(
            eventID: eventID,
            messageID: message.id,
            senderID: message.senderID
        )
    }

    private func recordIncomingChatPush(_ context: NotificationService.RemoteNotificationContext) -> UUID? {
        guard context.notificationType == Constants.Chat.messageNotificationType,
              let eventID = context.relatedEventID else {
            return nil
        }

        recordIncomingChatMessage(
            eventID: eventID,
            messageID: context.chatMessageID,
            senderID: context.senderID
        )

        return eventID
    }

    private func recordIncomingChatMessage(eventID: UUID, messageID: UUID?, senderID: UUID?) {
        guard senderID != userProfile?.id else {
            return
        }

        guard activeChatEventID != eventID else {
            markCachedChatMessagesRead(eventID: eventID)
            return
        }

        if let messageID {
            let countedMessageIDs = countedUnreadChatMessageIDsByEventID[eventID] ?? []

            guard !countedMessageIDs.contains(messageID) else {
                return
            }

            countedUnreadChatMessageIDsByEventID[eventID, default: []].insert(messageID)
        }

        userProfile = userProfile?.updatingChatMessageReadState(eventID: eventID, read: false)
        incrementUnreadChatCount(eventID: eventID)
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

    private func handleRemoteNotificationArrival(_ context: NotificationService.RemoteNotificationContext?) async {
        if let context,
           let chatEventID = recordIncomingChatPush(context) {
            await refreshCachedChatMessages(eventID: chatEventID)
        }

        // Refresh the current user profile when a remote notification arrives.
        // The profile stores notification IDs, while cachedNotifications stores app-only read state.
        // Full notification data are fetched when the user opens or refreshes the notification list page.
        await refreshCurrentProfile()
    }

    func preloadCachedChatMessages(eventIDs: [UUID]) async {
        for eventID in eventIDs where cachedChatMessagesByEventID[eventID] == nil {
            await refreshCachedChatMessages(eventID: eventID)
        }
    }

    func startChatMessagesRealtimeSubscriptions(eventIDs: [UUID]) {
        subscribedChatEventIDs.formUnion(eventIDs)

        guard !subscribedChatEventIDs.isEmpty else {
            return
        }

        startChatMessagesRealtimeSubscriptionIfNeeded()
    }

    func startChatMessagesRealtimeSubscription(eventID: UUID) {
        subscribedChatEventIDs.insert(eventID)
        startChatMessagesRealtimeSubscriptionIfNeeded()
    }

    private func startChatMessagesRealtimeSubscriptionIfNeeded() {
        // Listen for realtime update of chat messages table to update the local cached chat messages
        guard chatMessagesRealtimeTask == nil else {
            return
        }

        let client = SupabaseClientProvider.shared
        let channel = client.realtimeV2.channel("chat-messages")
        chatMessagesRealtimeChannel = channel

        chatMessagesRealtimeTask = Task { [weak self] in
            let inserts = channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "chat_messages"
            )

            do {
                await client.realtimeV2.setAuth()
                await client.realtimeV2.connect()
                try await channel.subscribeWithError()
                print("AppState: subscribed to realtime chat messages.")

                for await insert in inserts {
                    guard !Task.isCancelled else {
                        break
                    }

                    let chatMessage = try insert.decodeRecord(
                        as: ChatMessage.self,
                        decoder: Self.supabaseRealtimeDecoder
                    )

                    guard await self?.isSubscribedChatEvent(chatMessage.eventID) == true else {
                        continue
                    }

                    let messages = await self?.refreshCachedChatMessages(eventID: chatMessage.eventID) ?? []

                    guard let latestMessage = messages.last else {
                        continue
                    }

                    await MainActor.run {
                        // Increment unread chat count if the incoming message is not from the current user and the chat room is not currently active
                        self?.recordIncomingRealtimeChatMessage(latestMessage, eventID: chatMessage.eventID)
                    }
                }
            } catch is CancellationError {
                // Expected when signing out or deleting the account.
            } catch {
                print("AppState: chat messages realtime subscription failed: \(error.localizedDescription)")
            }
        }
    }

    func stopChatMessagesRealtimeSubscription() {
        chatMessagesRealtimeTask?.cancel()
        chatMessagesRealtimeTask = nil
        subscribedChatEventIDs = []

        guard let chatMessagesRealtimeChannel else {
            activeChatEventID = nil
            NotificationService.setActiveChatEventID(nil)
            return
        }

        self.chatMessagesRealtimeChannel = nil
        activeChatEventID = nil
        NotificationService.setActiveChatEventID(nil)

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
        NotificationService.setUserSignedIn(false)

        // Suppress foreground notifications after Supabase session is revoked
        NotificationService.unregisterRemoteNotifications()
        lastSavedDeviceToken = nil
        eventsRevision += 1
    }

    func finishDeletedAccountFlow() {
        stopChatMessagesRealtimeSubscription()
        NotificationService.setUserSignedIn(false)
        NotificationService.unregisterRemoteNotifications()
        lastSavedDeviceToken = nil
        googleSession = nil
        supabaseSession = nil
        userProfile = nil
        cachedNotifications = []
        cachedEventsByID = [:]
        cachedChatMessagesByEventID = [:]
        unreadChatCountsByEventID = [:]
        countedUnreadChatMessageIDsByEventID = [:]
        persistUnreadChatCounts()
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

        forceLocalSignOut(reason: nil)
    }

    private func forceLocalSignOut(reason: String?) {
        if let reason {
            print(reason)
        }

        stopChatMessagesRealtimeSubscription()
        NotificationService.setUserSignedIn(false)
        googleSession = nil
        supabaseSession = nil
        userProfile = nil
        cachedNotifications = []
        cachedEventsByID = [:]
        cachedChatMessagesByEventID = [:]
        unreadChatCountsByEventID = [:]
        countedUnreadChatMessageIDsByEventID = [:]
        persistUnreadChatCounts()
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
                    self?.forceLocalSignOut(
                        reason: "AppState: Supabase auth state changed to \(state.event.rawValue)."
                    )
                }
            }
        }
    }

    private func applyAuthenticatedState(supabaseSession: Session, userProfile: UserProfile) {
        self.supabaseSession = supabaseSession
        self.userProfile = userProfile
        NotificationService.setUserSignedIn(true)
        syncCachedNotifications(notificationIDs: userProfile.notifications)
        hydrateUnreadChatCountsFromProfile(userProfile)
        pruneUnreadChatCounts(validEventIDs: Set(userProfile.hostedEvents + userProfile.participatedEvents))
        authenticationState = userProfile.skillLevel == nil || userProfile.gender == nil ? .needsSkillLevel : .signedIn
        startChatMessagesRealtimeSubscriptions(eventIDs: Array(Set(userProfile.hostedEvents + userProfile.participatedEvents)))
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

    private func hydrateUnreadChatCountsFromProfile(_ profile: UserProfile) {
        let validEventIDs = Set(profile.hostedEvents + profile.participatedEvents)
        var hydratedCounts = unreadChatCountsByEventID.filter { eventID, count in
            validEventIDs.contains(eventID) && count > 0
        }

        for readState in profile.chatMessageReadStates where validEventIDs.contains(readState.id) {
            if readState.read {
                hydratedCounts[readState.id] = nil
                countedUnreadChatMessageIDsByEventID[readState.id] = nil
            } else {
                hydratedCounts[readState.id] = max(hydratedCounts[readState.id] ?? 0, 1)
            }
        }

        guard hydratedCounts != unreadChatCountsByEventID else {
            return
        }

        unreadChatCountsByEventID = hydratedCounts
        persistUnreadChatCounts()
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

    private func persistUnreadChatCounts() {
        let countsByID = unreadChatCountsByEventID.reduce(into: [String: Int]()) { result, item in
            result[item.key.uuidString] = item.value
        }

        UserDefaults.standard.set(countsByID, forKey: Constants.StorageKey.unreadChatCountsByEventID)
    }

    private static func loadUnreadChatCounts() -> [UUID: Int] {
        guard let storedCounts = UserDefaults.standard.dictionary(
            forKey: Constants.StorageKey.unreadChatCountsByEventID
        ) else {
            return [:]
        }

        return storedCounts.reduce(into: [UUID: Int]()) { result, item in
            let count = item.value as? Int ?? (item.value as? NSNumber)?.intValue ?? 0

            guard let eventID = UUID(uuidString: item.key), count > 0 else {
                return
            }

            result[eventID] = count
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
