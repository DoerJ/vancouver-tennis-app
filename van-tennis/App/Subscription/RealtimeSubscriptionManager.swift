import Foundation
import Supabase

@MainActor
final class RealtimeSubscriptionManager {
    typealias ProfileUpdateHandler = @MainActor @Sendable (UserProfile) -> Void
    typealias ProfileRecoveryHandler = @MainActor @Sendable () async -> Void

    // Profile Realtime is modeled as desired state plus one recoverable active attempt.
    // These tasks observe independent failure signals without creating parallel channels.
    private var profileRealtimeTask: Task<Void, Never>?
    private var profileRealtimeHealthTask: Task<Void, Never>?
    private var profileSocketStatusTask: Task<Void, Never>?
    private var profileHeartbeatTask: Task<Void, Never>?
    private var profileChannelStatusTask: Task<Void, Never>?
    private var profileRecoveryTask: Task<Void, Never>?
    private var profileRealtimeChannel: RealtimeChannelV2?
    private var profileSystemSubscription: RealtimeSubscription?
    // The user ID targeted by the current channel attempt.
    private var subscribedProfileID: UUID?
    private var profileRealtimeSubscribedAt: Date?
    // Identifies the current attempt so callbacks from replaced channels can be ignored.
    private var profileRealtimeAttemptID: UUID?
    // The user ID that should remain subscribed through disconnects and recovery attempts.
    private var desiredProfileID: UUID?
    private var profileUpdateHandler: ProfileUpdateHandler?
    private var profileRecoveryHandler: ProfileRecoveryHandler?
    private var profileRecoveryAttempt = 0
    // A new authenticated user should not inherit channels or socket auth from the previous session.
    private var shouldResetProfileSocketBeforeNextSubscription = false
    private var chatMessagesRealtimeTask: Task<Void, Never>?
    private var chatMessagesRealtimeChannel: RealtimeChannelV2?
    private var subscribedChatEventID: UUID?
    private var isSharedChatMessagesSubscriptionActive = false

    private static let realtimeDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            if let date = iso8601DateFormatter.date(from: dateString) {
                return date
            }

            if let date = iso8601DateFormatterWithoutFractionalSeconds.date(from: dateString) {
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

    func stopAll() {
        stopProfileRealtimeLifecycle()
        stopChatMessagesRealtimeSubscription()
    }

    /// Declares which profile should stay subscribed and repairs the subscription if needed.
    ///
    /// This method is idempotent, so authentication and app lifecycle events can safely call it
    /// without restarting an already healthy channel.
    /// - `onProfileUpdate` applies rows received through Realtime.
    /// - `onSubscriptionRecovered` fetches the latest profile because Realtime does not replay
    ///   database changes that occurred while the channel was disconnected.
    func ensureProfileRealtimeSubscription(
        userID: UUID,
        onProfileUpdate: @escaping ProfileUpdateHandler,
        onSubscriptionRecovered: @escaping ProfileRecoveryHandler
    ) {
        let isDifferentUser = desiredProfileID != userID

        desiredProfileID = userID
        profileUpdateHandler = onProfileUpdate
        profileRecoveryHandler = onSubscriptionRecovered

        if isDifferentUser {
            profileRecoveryAttempt = 0
            shouldResetProfileSocketBeforeNextSubscription = true
            cancelProfileMonitoring()
        }

        startProfileMonitoringIfNeeded()

        guard !isProfileSubscriptionHealthy,
              profileRecoveryTask == nil,
              profileRealtimeChannel?.status != .subscribing
        else {
            return
        }

        requestProfileRecovery(reason: isDifferentUser ? "authenticated user changed" : "subscription missing")
    }

    private var isProfileSubscriptionHealthy: Bool {
        guard let desiredProfileID else {
            return false
        }

        // A channel is usable only when its task, channel, socket, and intended user all agree.
        return subscribedProfileID == desiredProfileID
            && profileRealtimeTask != nil
            && profileRealtimeSubscribedAt != nil
            && profileRealtimeChannel?.status == .subscribed
            && SupabaseClientProvider.shared.realtimeV2.status == .connected
    }

    private func requestProfileRecovery(
        reason: String,
        delayNanoseconds: UInt64 = 0,
        force: Bool = false
    ) {
        guard desiredProfileID != nil,
              profileRecoveryTask == nil
        else {
            return
        }

        // Coalesce every failure signal into one recovery task. Socket, heartbeat, channel,
        // and periodic health checks can otherwise try to replace the same channel concurrently.
        let recoveryID = UUID()
        profileRecoveryTask = Task { [weak self] in
            if delayNanoseconds > 0 {
                do {
                    try await Task.sleep(nanoseconds: delayNanoseconds)
                } catch {
                    return
                }
            }

            guard let self else {
                return
            }

            guard self.desiredProfileID != nil,
                  force || !self.isProfileSubscriptionHealthy
            else {
                self.profileRecoveryTask = nil
                return
            }

            Logger.warn("Recovering profile realtime subscription. reason=\(reason)")
            await self.replaceProfileRealtimeSubscription(recoveryID: recoveryID)
            self.profileRecoveryTask = nil
        }
    }

    private func startProfileMonitoringIfNeeded() {
        let client = SupabaseClientProvider.shared

        // Recover when the underlying WebSocket disconnects after a successful subscription.
        if profileSocketStatusTask == nil {
            profileSocketStatusTask = Task { [weak self] in
                for await status in client.realtimeV2.statusChange {
                    guard !Task.isCancelled else {
                        return
                    }

                    guard status == .disconnected else {
                        continue
                    }

                    await MainActor.run {
                        guard let self,
                              self.profileRealtimeSubscribedAt != nil
                        else {
                            return
                        }

                        self.requestProfileRecovery(
                            reason: "socket disconnected",
                            delayNanoseconds: Constants.Realtime.profileRecoveryGraceIntervalNanoseconds,
                            force: true
                        )
                    }
                }
            }
        }

        // Heartbeat failures catch stale sockets that may not immediately report disconnected.
        if profileHeartbeatTask == nil {
            profileHeartbeatTask = Task { [weak self] in
                for await status in client.realtimeV2.heartbeat {
                    guard !Task.isCancelled else {
                        return
                    }

                    guard status == .timeout || status == .error else {
                        continue
                    }

                    await MainActor.run {
                        guard let self,
                              self.profileRealtimeSubscribedAt != nil
                        else {
                            return
                        }

                        self.requestProfileRecovery(
                            reason: "heartbeat \(String(describing: status))",
                            delayNanoseconds: Constants.Realtime.profileRecoveryGraceIntervalNanoseconds,
                            force: true
                        )
                    }
                }
            }
        }

        // The periodic check is a fallback for any SDK state transition missed by the streams above.
        guard profileRealtimeHealthTask == nil else {
            return
        }

        // Health monitor in 3-minute intervals
        profileRealtimeHealthTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(
                        nanoseconds: Constants.Realtime.profileHealthMonitorIntervalNanoseconds
                    )
                } catch {
                    return
                }

                await MainActor.run {
                    guard let self,
                          self.desiredProfileID != nil,
                          !self.isProfileSubscriptionHealthy
                    else {
                        return
                    }

                    self.requestProfileRecovery(reason: "health monitor detected an unhealthy subscription")
                }
            }
        }
    }

    private func cancelProfileMonitoring() {
        profileRealtimeHealthTask?.cancel()
        profileRealtimeHealthTask = nil
        profileSocketStatusTask?.cancel()
        profileSocketStatusTask = nil
        profileHeartbeatTask?.cancel()
        profileHeartbeatTask = nil
    }

    func startChatMessagesRealtimeSubscription(
        eventID: UUID,
        onChatMessageInsert: @escaping @MainActor (ChatMessage) -> Void
    ) {
        guard subscribedChatEventID != eventID || isSharedChatMessagesSubscriptionActive || chatMessagesRealtimeTask == nil else {
            return
        }

        stopChatMessagesRealtimeSubscription()
        subscribedChatEventID = eventID
        isSharedChatMessagesSubscriptionActive = false

        startChatMessagesRealtimeSubscription(
            channelName: "chat-messages-\(eventID.uuidString)",
            eventID: eventID,
            resetReason: "Reset before opening chat room subscription",
            onChatMessageInsert: onChatMessageInsert
        )
    }

    func startSharedChatMessagesRealtimeSubscription(
        onChatMessageInsert: @escaping @MainActor (ChatMessage) -> Void
    ) {
        guard !isSharedChatMessagesSubscriptionActive || chatMessagesRealtimeTask == nil else {
            return
        }

        stopChatMessagesRealtimeSubscription()
        subscribedChatEventID = nil
        isSharedChatMessagesSubscriptionActive = true

        startChatMessagesRealtimeSubscription(
            channelName: "chage-messages-share",
            eventID: nil,
            resetReason: "Reset before opening chat list subscription",
            onChatMessageInsert: onChatMessageInsert
        )
    }

    private func startChatMessagesRealtimeSubscription(
        channelName: String,
        eventID: UUID?,
        resetReason: String,
        onChatMessageInsert: @escaping @MainActor (ChatMessage) -> Void
    ) {
        let client = SupabaseClientProvider.chatRealtime

        chatMessagesRealtimeTask = Task {
            await client.realtimeV2.removeAllChannels()
            client.realtimeV2.disconnect(reason: resetReason)

            let channel = client.realtimeV2.channel(channelName)
            await MainActor.run {
                self.chatMessagesRealtimeChannel = channel
            }
            let inserts: AsyncStream<InsertAction> = if let eventID {
                channel.postgresChange(
                    InsertAction.self,
                    schema: "public",
                    table: "chat_messages",
                    filter: .eq("event_id", value: eventID.uuidString)
                )
            } else {
                channel.postgresChange(
                    InsertAction.self,
                    schema: "public",
                    table: "chat_messages"
                )
            }

            do {
                await client.realtimeV2.setAuth()
                await client.realtimeV2.connect()
                try await subscribeWithTimeout(channel)

                for await insert in inserts {
                    guard !Task.isCancelled else {
                        break
                    }

                    do {
                        let chatMessage = try insert.decodeRecord(
                            as: ChatMessage.self,
                            decoder: Self.realtimeDecoder
                        )

                        if let eventID, chatMessage.eventID != eventID {
                            continue
                        }

                        await MainActor.run {
                            onChatMessageInsert(chatMessage)
                        }
                    } catch {
                        Logger.error(
                            "Failed to decode chat realtime insert. "
                                + "channelName=\(channelName), "
                                + "eventID=\(eventID?.uuidString ?? "shared"), "
                                + "error=\(error.localizedDescription)"
                        )
                        continue
                    }
                }
            } catch is CancellationError {
            } catch {
                Logger.error(
                    "Chat realtime subscription failed. "
                        + "channelName=\(channelName), "
                        + "eventID=\(eventID?.uuidString ?? "shared"), "
                        + "socketStatus=\(client.realtimeV2.status), "
                        + "channelStatus=\(channel.status), "
                        + "error=\(error.localizedDescription)"
                )
            }
        }
    }

    private nonisolated func subscribeWithTimeout(_ channel: RealtimeChannelV2) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await channel.subscribeWithError()
            }

            group.addTask {
                // If the channel does not acknowledge the subscription within 10 seconds, throw an error.
                try await Task.sleep(nanoseconds: Constants.Chat.subscribeTimeoutNanoseconds)
                throw RealtimeSubscriptionManagerError.chatSubscribeTimedOut
            }

            try await group.next()
            group.cancelAll()
        }
    }

    func stopChatMessagesRealtimeSubscription() {
        chatMessagesRealtimeTask?.cancel()
        chatMessagesRealtimeTask = nil
        subscribedChatEventID = nil
        isSharedChatMessagesSubscriptionActive = false
        self.chatMessagesRealtimeChannel = nil
    }

    private func replaceProfileRealtimeSubscription(recoveryID: UUID) async {
        guard let userID = desiredProfileID,
              let onProfileUpdate = profileUpdateHandler,
              let onSubscriptionRecovered = profileRecoveryHandler
        else {
            return
        }

        // Fully retire the previous attempt before publishing a replacement as current state.
        profileRealtimeAttemptID = nil
        profileRealtimeSubscribedAt = nil
        profileRealtimeTask?.cancel()
        profileRealtimeTask = nil
        profileChannelStatusTask?.cancel()
        profileChannelStatusTask = nil
        profileSystemSubscription?.cancel()
        profileSystemSubscription = nil

        let channelToRemove = profileRealtimeChannel
        profileRealtimeChannel = nil
        subscribedProfileID = nil

        let client = SupabaseClientProvider.shared

        if let channelToRemove {
            await client.realtimeV2.removeChannel(channelToRemove)
        }

        if shouldResetProfileSocketBeforeNextSubscription {
            await client.realtimeV2.removeAllChannels()
            client.realtimeV2.disconnect(reason: "Reset before subscribing authenticated profile")

            guard !Task.isCancelled,
                  desiredProfileID == userID
            else {
                return
            }

            shouldResetProfileSocketBeforeNextSubscription = false
        }

        guard !Task.isCancelled,
              desiredProfileID == userID
        else {
            return
        }

        let attemptID = UUID()
        // A unique topic prevents delayed cleanup from removing a newer channel for the same user.
        let channel = client.realtimeV2.channel(
            "profile-\(userID.uuidString)-\(attemptID.uuidString)"
        )

        profileRealtimeChannel = channel
        subscribedProfileID = userID
        profileRealtimeAttemptID = attemptID

        // Supabase requires Postgres change callbacks to be registered before subscribe().
        let updates = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "profiles",
            filter: .eq("id", value: userID.uuidString)
        )

        profileSystemSubscription = channel.onSystem { [weak self] message in
            guard message.status != .ok else {
                return
            }

            Task { @MainActor [weak self] in
                guard let self,
                      self.profileRealtimeAttemptID == attemptID
                else {
                    return
                }

                Logger.error(
                    "Profile realtime channel received a system error. "
                        + "userID=\(userID), "
                        + "payload=\(message.payload)"
                )
                self.requestProfileRecovery(
                    reason: "channel system error",
                    delayNanoseconds: Constants.Realtime.profileRetryBaseIntervalNanoseconds,
                    force: true
                )
            }
        }

        profileRealtimeTask = Task { [weak self] in
            do {
                await client.realtimeV2.setAuth()
                await client.realtimeV2.connect()
                try await channel.subscribeWithError()

                await MainActor.run {
                    guard self?.profileRealtimeAttemptID == attemptID else {
                        return
                    }

                    self?.profileRealtimeSubscribedAt = Date()
                    self?.profileRecoveryAttempt = 0
                }

                await MainActor.run {
                    self?.startProfileChannelStatusMonitor(
                        channel: channel,
                        userID: userID,
                        attemptID: attemptID
                    )
                }

                Logger.info(
                    "Profile realtime subscription active. "
                        + "userID=\(userID), "
                    + "recoveryID=\(recoveryID)"
                )

                // Reconcile any profile updates missed while this channel was unavailable.
                await onSubscriptionRecovered()

                for await update in updates {
                    guard !Task.isCancelled else {
                        throw CancellationError()
                    }

                    do {
                        let updatedProfile = try update.decodeRecord(
                            as: UserProfile.self,
                            decoder: Self.realtimeDecoder
                        )

                        guard updatedProfile.id == userID else {
                            continue
                        }

                        await onProfileUpdate(updatedProfile)
                    } catch {
                        Logger.error(
                            "Failed to decode profile realtime update. "
                                + "userID=\(userID), "
                                + "error=\(error.localizedDescription)"
                        )
                        continue
                    }
                }

                guard !Task.isCancelled,
                      self?.desiredProfileID == userID,
                      self?.profileRealtimeAttemptID == attemptID
                else {
                    return
                }

                throw RealtimeSubscriptionManagerError.profileUpdateStreamEnded
            } catch is CancellationError {
                await self?.handleProfileRealtimeAttemptEnded(
                    userID: userID,
                    attemptID: attemptID,
                    errorDescription: "cancelled"
                )
            } catch {
                guard !Task.isCancelled,
                      self?.desiredProfileID == userID,
                      self?.profileRealtimeAttemptID == attemptID
                else {
                    return
                }

                Logger.error(
                    "Profile realtime subscription failed. "
                        + "userID=\(userID), "
                        + "socketStatus=\(client.realtimeV2.status), "
                        + "channelStatus=\(channel.status), "
                        + "error=\(error.localizedDescription)"
                )

                await self?.handleProfileRealtimeAttemptEnded(
                    userID: userID,
                    attemptID: attemptID,
                    errorDescription: error.localizedDescription
                )
            }
        }
    }

    private func startProfileChannelStatusMonitor(
        channel: RealtimeChannelV2,
        userID: UUID,
        attemptID: UUID
    ) {
        profileChannelStatusTask?.cancel()
        profileChannelStatusTask = Task { [weak self] in
            for await status in channel.statusChange {
                guard !Task.isCancelled else {
                    return
                }

                guard status == .unsubscribed else {
                    continue
                }

                await MainActor.run {
                    guard let self,
                          self.profileRealtimeAttemptID == attemptID,
                          self.profileRealtimeSubscribedAt != nil
                    else {
                        return
                    }

                    Logger.warn("Profile realtime channel became unsubscribed. userID=\(userID)")
                    self.requestProfileRecovery(
                        reason: "channel became unsubscribed",
                        force: true
                    )
                }
                return
            }
        }
    }

    private func handleProfileRealtimeAttemptEnded(
        userID: UUID,
        attemptID: UUID,
        errorDescription: String
    ) {
        guard desiredProfileID == userID,
              profileRealtimeAttemptID == attemptID
        else {
            return
        }

        profileRealtimeTask = nil
        profileRealtimeSubscribedAt = nil
        profileRealtimeAttemptID = nil
        profileChannelStatusTask?.cancel()
        profileChannelStatusTask = nil
        profileSystemSubscription?.cancel()
        profileSystemSubscription = nil
        profileRecoveryAttempt += 1

        // Retry quickly at first, then cap the exponential delay to avoid a reconnect storm.
        let delay = profileRetryDelayNanoseconds(attempt: profileRecoveryAttempt)
        Logger.warn(
            "Scheduling profile realtime recovery. "
                + "userID=\(userID), "
                + "attempt=\(profileRecoveryAttempt), "
                + "reason=\(errorDescription)"
        )
        requestProfileRecovery(
            reason: errorDescription,
            delayNanoseconds: delay,
            force: true
        )
    }

    private func profileRetryDelayNanoseconds(attempt: Int) -> UInt64 {
        let cappedAttempt = min(max(attempt - 1, 0), Constants.Realtime.profileRetryMaximumExponent)
        let multiplier = UInt64(1 << cappedAttempt)
        return Constants.Realtime.profileRetryBaseIntervalNanoseconds * multiplier
    }

    private func stopProfileRealtimeLifecycle() {
        // Clearing desired state first prevents an in-flight callback from scheduling recovery
        // after logout, account deletion, or a switch to another authenticated user.
        desiredProfileID = nil
        profileUpdateHandler = nil
        profileRecoveryHandler = nil
        profileRecoveryAttempt = 0
        shouldResetProfileSocketBeforeNextSubscription = true
        profileRealtimeSubscribedAt = nil
        profileRealtimeAttemptID = nil
        subscribedProfileID = nil

        cancelProfileMonitoring()
        profileRecoveryTask?.cancel()
        profileRecoveryTask = nil
        profileRealtimeTask?.cancel()
        profileRealtimeTask = nil
        profileChannelStatusTask?.cancel()
        profileChannelStatusTask = nil
        profileSystemSubscription?.cancel()
        profileSystemSubscription = nil

        guard let channelToRemove = profileRealtimeChannel else {
            return
        }

        profileRealtimeChannel = nil

        Task {
            await SupabaseClientProvider.shared.realtimeV2.removeChannel(channelToRemove)
        }
    }
}

private enum RealtimeSubscriptionManagerError: LocalizedError {
    case chatSubscribeTimedOut
    case profileUpdateStreamEnded

    var errorDescription: String? {
        switch self {
        case .chatSubscribeTimedOut:
            return "Chat realtime subscription timed out while waiting for channel join acknowledgement."
        case .profileUpdateStreamEnded:
            return "Profile realtime update stream ended unexpectedly."
        }
    }
}
