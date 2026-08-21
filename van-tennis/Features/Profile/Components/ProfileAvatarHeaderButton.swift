import SwiftUI

struct ProfileAvatarHeaderButton: View {
    let avatarURL: URL?
    let action: () -> Void

    private let size: CGFloat = 46

    var body: some View {
        Button(action: action) {
            ProfileAvatarImageView(url: avatarURL, size: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppContent.string("common.profile"))
    }
}
