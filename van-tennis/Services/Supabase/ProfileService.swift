import Foundation
import Supabase

struct ProfileService {
    private let client = SupabaseClientProvider.shared
    private let deviceTokenService = DeviceTokenService()
    private let blacklistService = BlacklistService()

    func findOrCreateProfile(for user: User) async throws -> UserProfile {
        // uuid is used as the primary key to query the profile
        if let existingProfile = try await findProfile(userID: user.id) {
            print("ProfileService: found existing profile. userID=\(user.id).")
            return existingProfile
        }

        print("ProfileService: no existing profile found. creating new profile. userID=\(user.id), hasCurrentDeviceToken=\(NotificationService.currentDeviceToken != nil).")

        if try await blacklistService.isCurrentUserEmailBlacklisted() {
            throw ProfileServiceError.emailBlacklisted
        }

        let newProfile = NewUserProfile(
            id: user.id,
            email: user.email,
            displayName: defaultDisplayName(for: user),
            avatarURL: defaultAvatarURL(for: user),
            skillLevel: nil,
            gender: nil,
            hostedEvents: [],
            participatedEvents: [],
            pendingEvents: [],
            notifications: [],
            socialTags: [],
            isAllEventsRead: true,
            isAllNotificationsRead: true,
            chatMessageReadStates: []
        )

        let createdProfile: UserProfile = try await client
            .from("profiles")
            .insert(newProfile)
            .select()
            .single()
            .execute()
            .value

        print("ProfileService: created new profile. userID=\(createdProfile.id), hasCurrentDeviceToken=\(NotificationService.currentDeviceToken != nil).")
        await saveCurrentDeviceTokenIfAvailable(userID: createdProfile.id)

        return createdProfile
    }

    func findProfile(userID: UUID) async throws -> UserProfile? {
        let profiles: [UserProfile] = try await client
            .from("profiles")
            .select()
            .eq("id", value: userID.uuidString)
            .execute()
            .value

        return profiles.first
    }

    func isDisplayNameTaken(_ displayName: String, excluding userID: UUID) async throws -> Bool {
        let profiles: [UserProfile] = try await client
            .from("profiles")
            .select()
            .eq("display_name", value: displayName)
            .neq("id", value: userID.uuidString)
            .limit(1)
            .execute()
            .value

        return !profiles.isEmpty
    }

    func fetchProfiles(userIDs: [UUID]) async throws -> [UserProfile] {
        guard !userIDs.isEmpty else {
            return []
        }

        return try await client
            .from("profiles")
            .select()
            .in("id", values: userIDs.map(\.uuidString))
            .execute()
            .value
    }

    func updateProfile(
        userID: UUID,
        displayName: String? = nil,
        skillLevel: SkillLevel? = nil,
        gender: Gender? = nil,
        hostedEvents: [UUID]? = nil,
        participatedEvents: [UUID]? = nil,
        pendingEvents: [UUID]? = nil,
        notifications: [UUID]? = nil,
        socialTags: [String]? = nil,
        isAllEventsRead: Bool? = nil,
        isAllNotificationsRead: Bool? = nil,
        chatMessageReadStates: [ChatMessageReadState]? = nil
    ) async throws -> UserProfile {
        try await client
            .from("profiles")
            .update(
                UpdateUserProfile(
                    displayName: displayName,
                    skillLevel: skillLevel,
                    gender: gender,
                    hostedEvents: hostedEvents,
                    participatedEvents: participatedEvents,
                    pendingEvents: pendingEvents,
                    notifications: notifications,
                    socialTags: socialTags,
                    isAllEventsRead: isAllEventsRead,
                    isAllNotificationsRead: isAllNotificationsRead,
                    chatMessageReadStates: chatMessageReadStates
                )
            )
            .eq("id", value: userID.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func appendHostedEvent(userID: UUID, eventID: UUID) async throws -> UserProfile {
        guard let profile = try await findProfile(userID: userID) else {
            throw ProfileServiceError.profileNotFound
        }

        var hostedEvents = profile.hostedEvents

        if !hostedEvents.contains(eventID) {
            hostedEvents.append(eventID)
        }

        return try await updateProfile(
            userID: userID,
            hostedEvents: hostedEvents,
            isAllEventsRead: false
        )
    }

    func removeHostedEvent(userID: UUID, eventID: UUID) async throws -> UserProfile {
        guard let profile = try await findProfile(userID: userID) else {
            throw ProfileServiceError.profileNotFound
        }

        let hostedEvents = profile.hostedEvents.filter { $0 != eventID }

        return try await updateProfile(
            userID: userID,
            hostedEvents: hostedEvents
        )
    }

    func markCurrentUserChatMessagesRead(eventID: UUID) async throws {
        try await client
            .rpc(
                "mark_current_user_chat_messages_read",
                params: MarkCurrentUserChatMessagesReadParams(eventID: eventID)
            )
            .execute()
    }

    func deleteAccountProfileData() async throws {
        try await client
            .rpc("delete_account_profile_data")
            .execute()
    }

    private func defaultDisplayName(for user: User) -> String {
        for key in ["name", "full_name", "display_name"] {
            if let displayName = user.userMetadata[key]?.stringValue,
               !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return displayName
            }
        }

        guard let email = user.email, let username = email.split(separator: "@").first else {
            return AppContent.string("profile.defaultDisplayName")
        }

        return String(username)
    }

    private func saveCurrentDeviceTokenIfAvailable(userID: UUID) async {
        guard let deviceToken = NotificationService.currentDeviceToken else {
            print("ProfileService: no APNs device token available when creating profile. userID=\(userID).")
            return
        }

        do {
            print("ProfileService: saving device token for new profile. userID=\(userID), tokenSuffix=\(deviceToken.suffix(8)).")
            try await deviceTokenService.saveDeviceToken(
                userID: userID,
                deviceToken: deviceToken
            )
            print("ProfileService: saved device token for new profile. userID=\(userID), tokenSuffix=\(deviceToken.suffix(8)).")
        } catch {
            print("ProfileService: failed to save device token for new profile. userID=\(userID), tokenSuffix=\(deviceToken.suffix(8)), error=\(error.localizedDescription).")
        }
    }

    private func defaultAvatarURL(for user: User) -> URL? {
        for key in ["avatar_url", "picture"] {
            if let urlString = user.userMetadata[key]?.stringValue,
               let url = URL(string: urlString) {
                return url
            }
        }

        return nil
    }
}

private struct MarkCurrentUserChatMessagesReadParams: Encodable {
    let eventID: UUID

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
    }
}

enum ProfileServiceError: LocalizedError {
    case profileNotFound
    case emailBlacklisted

    var errorDescription: String? {
        switch self {
        case .profileNotFound:
            return AppContent.string("errors.userProfileNotFound")
        case .emailBlacklisted:
            return AppContent.string("auth.login.emailBlacklisted")
        }
    }
}
