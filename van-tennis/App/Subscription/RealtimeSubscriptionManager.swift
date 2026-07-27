import Foundation
import Supabase

@MainActor
final class RealtimeSubscriptionManager {
    private var profileRealtimeTask: Task<Void, Never>?
    private var profileRealtimeChannel: RealtimeChannelV2?
    private var subscribedProfileID: UUID?

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

    func startSubscriptions(
        userID: UUID,
        eventIDs: [UUID],
        onProfileUpdate: @escaping @MainActor (UserProfile) -> Void
    ) {
        startProfileRealtimeSubscription(userID: userID, onProfileUpdate: onProfileUpdate)

        // Temporarily disabled while debugging the profiles realtime subscription.
        // startChatMessagesRealtimeSubscription(eventIDs: eventIDs)
        _ = eventIDs
    }

    func stopAll() {
        stopProfileRealtimeSubscription()

        // Temporarily disabled while debugging the profiles realtime subscription.
        // stopChatMessagesRealtimeSubscription()
    }

    private func startProfileRealtimeSubscription(
        userID: UUID,
        onProfileUpdate: @escaping @MainActor (UserProfile) -> Void
    ) {
        print("RealtimeSubscriptionManager: start profile realtime subscription requested for user \(userID).")

        guard subscribedProfileID != userID else {
            print("RealtimeSubscriptionManager: profile realtime subscription already active for user \(userID).")
            return
        }

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
                print("RealtimeSubscriptionManager: realtime socket status before profile connect: \(client.realtimeV2.status).")
                await client.realtimeV2.setAuth()
                await client.realtimeV2.connect()
                print("RealtimeSubscriptionManager: realtime socket status before profile subscribe: \(client.realtimeV2.status), channel status: \(channel.status).")
                try await channel.subscribeWithError()
                print("RealtimeSubscriptionManager: subscribed to realtime profile updates. Socket status: \(client.realtimeV2.status), channel status: \(channel.status).")

                for await update in updates {
                    guard !Task.isCancelled else {
                        break
                    }

                    print("RealtimeSubscriptionManager: received realtime profile update payload for user \(userID).")

                    do {
                        let updatedProfile = try update.decodeRecord(
                            as: UserProfile.self,
                            decoder: Self.realtimeDecoder
                        )

                        print(
                            "RealtimeSubscriptionManager: decoded realtime profile update. isAllEventsRead=\(updatedProfile.isAllEventsRead), hostedEvents=\(updatedProfile.hostedEvents.count), participatedEvents=\(updatedProfile.participatedEvents.count)."
                        )

                        await MainActor.run {
                            onProfileUpdate(updatedProfile)
                        }
                    } catch {
                        print("RealtimeSubscriptionManager: failed to decode realtime profile update: \(error.localizedDescription)")
                    }
                }
            } catch is CancellationError {
                // Expected when signing out or deleting the account.
            } catch {
                print("RealtimeSubscriptionManager: profile realtime subscription failed: \(error.localizedDescription)")
            }
        }
    }

    private func stopProfileRealtimeSubscription() {
        print("RealtimeSubscriptionManager: stopping profile realtime subscription.")
        profileRealtimeTask?.cancel()
        profileRealtimeTask = nil
        subscribedProfileID = nil

        guard let profileRealtimeChannel else {
            print("RealtimeSubscriptionManager: no profile realtime channel to remove.")
            return
        }

        self.profileRealtimeChannel = nil

        Task {
            print("RealtimeSubscriptionManager: removing profile realtime channel.")
            await SupabaseClientProvider.shared.realtimeV2.removeChannel(profileRealtimeChannel)
        }
    }
}
