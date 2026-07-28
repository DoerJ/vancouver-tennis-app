import Foundation
import Supabase

@MainActor
final class RealtimeSubscriptionManager {
    private var profileRealtimeTask: Task<Void, Never>?
    private var profileRealtimeChannel: RealtimeChannelV2?
    private var subscribedProfileID: UUID?
    private var profileRealtimeSubscribedAt: Date?
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
        stopProfileRealtimeSubscription()
        stopChatMessagesRealtimeSubscription()
    }

    func refreshProfileRealtimeSubscriptionIfNeeded(
        userID: UUID,
        onProfileUpdate: @escaping @MainActor (UserProfile) -> Void
    ) {
        guard subscribedProfileID == userID,
              profileRealtimeTask != nil,
              profileRealtimeChannel != nil
        else {
            restartProfileRealtimeSubscription(userID: userID, onProfileUpdate: onProfileUpdate)
            return
        }

        guard profileRealtimeSubscribedAt != nil else {
            restartProfileRealtimeSubscription(userID: userID, onProfileUpdate: onProfileUpdate)
            return
        }

        let socketStatus = SupabaseClientProvider.shared.realtimeV2.status
        let channelStatus = profileRealtimeChannel?.status

        guard socketStatus != .connected || channelStatus != .subscribed else {
            return
        }

        restartProfileRealtimeSubscription(userID: userID, onProfileUpdate: onProfileUpdate)
    }

    func restartProfileRealtimeSubscription(
        userID: UUID,
        onProfileUpdate: @escaping @MainActor (UserProfile) -> Void
    ) {
        print("RealtimeSubscriptionManager: restart profile subscription requested. userID=\(userID), socketStatus=\(SupabaseClientProvider.shared.realtimeV2.status), channelStatus=\(profileRealtimeChannel.map { "\($0.status)" } ?? "nil").")
        let channelToRemove = clearProfileRealtimeSubscriptionState()

        Task { [weak self] in
            if let channelToRemove {
                print("RealtimeSubscriptionManager: removing previous profile channel before restart. userID=\(userID).")
                await SupabaseClientProvider.shared.realtimeV2.removeChannel(channelToRemove)
            }

            await MainActor.run {
                print("RealtimeSubscriptionManager: starting profile subscription after restart cleanup. userID=\(userID), socketStatus=\(SupabaseClientProvider.shared.realtimeV2.status).")
                self?.startProfileRealtimeSubscription(
                    userID: userID,
                    onProfileUpdate: onProfileUpdate
                )
            }
        }
    }

    func startProfileRealtimeSubscriptionAfterSocketCleanup(
        userID: UUID,
        onProfileUpdate: @escaping @MainActor (UserProfile) -> Void
    ) {
        print("RealtimeSubscriptionManager: profile socket cleanup requested before start. userID=\(userID), socketStatus=\(SupabaseClientProvider.shared.realtimeV2.status), channelStatus=\(profileRealtimeChannel.map { "\($0.status)" } ?? "nil").")

        _ = clearProfileRealtimeSubscriptionState()
        let client = SupabaseClientProvider.shared

        Task { [weak self] in
            await client.realtimeV2.removeAllChannels()
            client.realtimeV2.disconnect(reason: "Reset before opening profile subscription from main tab")

            await MainActor.run {
                print("RealtimeSubscriptionManager: starting profile subscription after socket cleanup. userID=\(userID), socketStatus=\(client.realtimeV2.status).")
                self?.startProfileRealtimeSubscription(
                    userID: userID,
                    onProfileUpdate: onProfileUpdate
                )
            }
        }
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
                        continue
                    }
                }
            } catch is CancellationError {
            } catch {
            }
        }
    }

    private nonisolated func subscribeWithTimeout(_ channel: RealtimeChannelV2) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await channel.subscribeWithError()
            }

            group.addTask {
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

    private func startProfileRealtimeSubscription(
        userID: UUID,
        onProfileUpdate: @escaping @MainActor (UserProfile) -> Void
    ) {
        print("RealtimeSubscriptionManager: start profile subscription requested. userID=\(userID), currentSubscribedProfileID=\(subscribedProfileID?.uuidString ?? "nil"), socketStatus=\(SupabaseClientProvider.shared.realtimeV2.status), channelStatus=\(profileRealtimeChannel.map { "\($0.status)" } ?? "nil").")

        if subscribedProfileID == userID {
            guard profileRealtimeTask != nil,
                  profileRealtimeChannel?.status == .subscribed,
                  profileRealtimeSubscribedAt != nil
            else {
                print("RealtimeSubscriptionManager: existing profile subscription is not healthy; restarting. userID=\(userID), hasTask=\(profileRealtimeTask != nil), channelStatus=\(profileRealtimeChannel.map { "\($0.status)" } ?? "nil"), subscribedAt=\(profileRealtimeSubscribedAt?.description ?? "nil").")
                restartProfileRealtimeSubscription(
                    userID: userID,
                    onProfileUpdate: onProfileUpdate
                )
                return
            }

            print("RealtimeSubscriptionManager: profile subscription already healthy. userID=\(userID), channelStatus=\(profileRealtimeChannel.map { "\($0.status)" } ?? "nil").")
            return
        }

        print("RealtimeSubscriptionManager: creating new profile channel. userID=\(userID).")
        stopProfileRealtimeSubscription()
        subscribedProfileID = userID

        let client = SupabaseClientProvider.shared
        let channel = client.realtimeV2.channel("profile-\(userID.uuidString)")
        profileRealtimeChannel = channel

        profileRealtimeTask = Task {
            let updates = channel.postgresChange(
                UpdateAction.self,
                schema: "public",
                table: "profiles",
                filter: .eq("id", value: userID.uuidString)
            )

            do {
                print("RealtimeSubscriptionManager: setting auth for profile realtime. userID=\(userID).")
                await client.realtimeV2.setAuth()
                print("RealtimeSubscriptionManager: connecting profile realtime socket. userID=\(userID), socketStatusBefore=\(client.realtimeV2.status).")
                await client.realtimeV2.connect()
                print("RealtimeSubscriptionManager: subscribing profile channel. userID=\(userID), socketStatus=\(client.realtimeV2.status), channelStatus=\(channel.status).")
                try await channel.subscribeWithError()
                await MainActor.run {
                    self.profileRealtimeSubscribedAt = Date()
                }
                print("RealtimeSubscriptionManager: profile realtime subscription succeeded. userID=\(userID), socketStatus=\(client.realtimeV2.status), channelStatus=\(channel.status).")

                for await update in updates {
                    guard !Task.isCancelled else {
                        break
                    }

                    do {
                        let updatedProfile = try update.decodeRecord(
                            as: UserProfile.self,
                            decoder: Self.realtimeDecoder
                        )

                        print("RealtimeSubscriptionManager: received profile realtime update. expectedUserID=\(userID), returnedUserID=\(updatedProfile.id).")
                        await MainActor.run {
                            onProfileUpdate(updatedProfile)
                        }
                    } catch {
                        print("RealtimeSubscriptionManager: failed to decode profile realtime update. userID=\(userID), error=\(error.localizedDescription).")
                        continue
                    }
                }
            } catch is CancellationError {
                print("RealtimeSubscriptionManager: profile realtime subscription cancelled. userID=\(userID).")
            } catch {
                print("RealtimeSubscriptionManager: profile realtime subscription failed. userID=\(userID), socketStatus=\(client.realtimeV2.status), channelStatus=\(channel.status), error=\(error.localizedDescription).")
            }
        }
    }


    private func stopProfileRealtimeSubscription() {
        let channelToRemove = clearProfileRealtimeSubscriptionState()

        guard let channelToRemove else {
            print("RealtimeSubscriptionManager: no profile channel to stop.")
            return
        }

        print("RealtimeSubscriptionManager: stopping profile realtime subscription.")
        Task {
            await SupabaseClientProvider.shared.realtimeV2.removeChannel(channelToRemove)
        }
    }

    private func clearProfileRealtimeSubscriptionState() -> RealtimeChannelV2? {
        profileRealtimeTask?.cancel()
        profileRealtimeTask = nil
        subscribedProfileID = nil
        profileRealtimeSubscribedAt = nil

        let channelToRemove = profileRealtimeChannel
        self.profileRealtimeChannel = nil
        return channelToRemove
    }
}

private enum RealtimeSubscriptionManagerError: LocalizedError {
    case chatSubscribeTimedOut

    var errorDescription: String? {
        switch self {
        case .chatSubscribeTimedOut:
            return "Chat realtime subscription timed out while waiting for channel join acknowledgement."
        }
    }
}
