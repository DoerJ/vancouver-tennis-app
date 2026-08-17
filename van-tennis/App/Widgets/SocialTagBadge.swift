import SwiftUI

struct SocialTagBadge: View {
    let text: String
    let color: Color
    let horizontalPadding: CGFloat
    let showsShadow: Bool
    let shadowOpacity: Double
    let shadowRadius: CGFloat
    let showsCheckmark: Bool
    let checkmarkSize: CGFloat

    init(
        _ text: String,
        color: Color = RallyDiscoverStyle.accentGreen,
        horizontalPadding: CGFloat = 12,
        showsShadow: Bool = false,
        shadowOpacity: Double = 1,
        shadowRadius: CGFloat = 18,
        showsCheckmark: Bool = false,
        checkmarkSize: CGFloat = 8
    ) {
        self.text = text
        self.color = color
        self.horizontalPadding = horizontalPadding
        self.showsShadow = showsShadow
        self.shadowOpacity = shadowOpacity
        self.shadowRadius = shadowRadius
        self.showsCheckmark = showsCheckmark
        self.checkmarkSize = checkmarkSize
    }

    var body: some View {
        HStack(spacing: 5) {
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if showsCheckmark {
                Image(systemName: "checkmark")
                    .font(.rally(size: checkmarkSize, weight: .bold))
            }
        }
        .font(.rally(size: 10, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, horizontalPadding)
        .frame(height: 22)
        .background(color, in: Capsule())
        .shadow(
            color: RallyDiscoverStyle.shadow.opacity(showsShadow ? shadowOpacity : 0),
            radius: showsShadow ? shadowRadius : 0,
            x: 0,
            y: showsShadow ? 8 : 0
        )
    }
}
