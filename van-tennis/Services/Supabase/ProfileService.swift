import Foundation
import Supabase

struct ProfileService {
    private let client = SupabaseClientProvider.shared

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
            hostedEvents: []
        )

        return try await client
            .from("profiles")
            .insert(newProfile)
            .select()
            .single()
            .execute()
            .value
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

    func updateProfile(
        userID: UUID,
        displayName: String? = nil,
        skillLevel: SkillLevel? = nil,
        hostedEvents: [UUID]? = nil
    ) async throws -> UserProfile {
        try await client
            .from("profiles")
            .update(
                UpdateUserProfile(
                    displayName: displayName,
                    skillLevel: skillLevel,
                    hostedEvents: hostedEvents
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
