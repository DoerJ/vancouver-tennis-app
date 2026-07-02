import SwiftUI

struct HostSummaryView: View {
    let host: UserProfile?

    var body: some View {
        Section("Host") {
            if let host {
                ProfileSummaryRow(profile: host, fallbackTitle: "Host")
            } else {
                Label("Host profile unavailable", systemImage: "person.crop.circle.badge.questionmark")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ProfileSummaryRow: View {
    let profile: UserProfile
    let fallbackTitle: String
    let titleSuffix: String?

    init(profile: UserProfile, fallbackTitle: String, titleSuffix: String? = nil) {
        self.profile = profile
        self.fallbackTitle = fallbackTitle
        self.titleSuffix = titleSuffix
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(displayTitle)
                .font(.body)

            Text("Skill level \(profile.skillLevel?.rawValue ?? "Not set")")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !profile.socialTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(profile.socialTags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.secondary.opacity(0.12), in: Capsule())
                        }
                    }
                }
            }
        }
    }

    private var displayTitle: String {
        let title = profile.displayName.isEmpty ? fallbackTitle : profile.displayName

        guard let titleSuffix else {
            return title
        }

        return "\(title) \(titleSuffix)"
    }
}
