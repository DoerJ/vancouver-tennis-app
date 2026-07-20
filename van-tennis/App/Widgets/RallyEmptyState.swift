import SwiftUI

struct RallyEmptyState: View {
    let iconName: String
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 10) {
            Image(iconName)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(RallyDiscoverStyle.ink)
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(RallyDiscoverStyle.ink)
                .multilineTextAlignment(.center)

            Text(description)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(RallyDiscoverStyle.mutedText)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding(.horizontal, 28)
    }
}
