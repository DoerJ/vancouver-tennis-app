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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(profile.displayName.isEmpty ? fallbackTitle : profile.displayName)
                .font(.body)

            Text("Skill level \(profile.skillLevel?.rawValue ?? "Not set")")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
