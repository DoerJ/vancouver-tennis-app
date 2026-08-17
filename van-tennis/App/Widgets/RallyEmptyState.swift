import SwiftUI

struct RallyEmptyState: View {
    let iconName: String
    let title: String
    let description: String
    let titleFontSize: CGFloat
    let descriptionFontSize: CGFloat

    init(
        iconName: String,
        title: String,
        description: String,
        titleFontSize: CGFloat = 15,
        descriptionFontSize: CGFloat = 13
    ) {
        self.iconName = iconName
        self.title = title
        self.description = description
        self.titleFontSize = titleFontSize
        self.descriptionFontSize = descriptionFontSize
    }

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
                .font(.rally(size: titleFontSize, weight: .semibold))
                .foregroundStyle(RallyDiscoverStyle.ink)
                .multilineTextAlignment(.center)

            Text(description)
                .font(.rally(size: descriptionFontSize, weight: .medium))
                .foregroundStyle(RallyDiscoverStyle.mutedText)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding(.horizontal, 28)
    }
}
