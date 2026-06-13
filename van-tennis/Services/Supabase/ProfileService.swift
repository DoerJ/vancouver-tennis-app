import Foundation
import Supabase

struct ProfileService {
    private let client = SupabaseClientProvider.shared
    private let deviceTokenService = DeviceTokenService()

    func findOrCreateProfile(for user: User) async throws -> UserProfile {
        // uuid is used as the primary key to query the profile
        if let existingProfile = try await findProfile(userID: user.id) {
            return existingProfile
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
            notifications: [],
            socialTags: []
        )

        let createdProfile: UserProfile = try await client
            .from("profiles")
            .insert(newProfile)
            .select()
            .single()
            .execute()
            .value

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
        notifications: [UUID]? = nil,
        socialTags: [String]? = nil
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
                    notifications: notifications,
                    socialTags: socialTags
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
            hostedEvents: hostedEvents
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
            return "Tennis Player"
        }

        return String(username)
    }

    private func saveCurrentDeviceTokenIfAvailable(userID: UUID) async {
        guard let deviceToken = NotificationService.currentDeviceToken else {
            print("ProfileService: no APNs device token available when creating profile.")
            return
        }

        do {
            try await deviceTokenService.saveDeviceToken(
                userID: userID,
                deviceToken: deviceToken
            )
            print("ProfileService: saved device token for new profile.")
        } catch {
            print("ProfileService: failed to save device token for new profile: \(error.localizedDescription)")
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

enum ProfileServiceError: LocalizedError {
    case profileNotFound

    var errorDescription: String? {
        switch self {
        case .profileNotFound:
            return "User profile was not found."
        }
    }
}
