import SwiftUI

struct RallyBadge: View {
    let text: String
    let color: Color
    let fontSize: CGFloat
    let width: CGFloat?
    let minWidth: CGFloat?
    let maxWidth: CGFloat?
    let height: CGFloat
    let horizontalPadding: CGFloat
    let minimumScaleFactor: CGFloat
    let showsShadow: Bool
    let shadowRadius: CGFloat

    init(
        _ text: String,
        color: Color,
        fontSize: CGFloat = 10,
        width: CGFloat? = nil,
        minWidth: CGFloat? = 71,
        maxWidth: CGFloat? = nil,
        height: CGFloat = 22,
        horizontalPadding: CGFloat = 8,
        minimumScaleFactor: CGFloat = 0.75,
        showsShadow: Bool = false,
        shadowRadius: CGFloat = 9
    ) {
        self.text = text
        self.color = color
        self.fontSize = fontSize
        self.width = width
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.height = height
        self.horizontalPadding = horizontalPadding
        self.minimumScaleFactor = minimumScaleFactor
        self.showsShadow = showsShadow
        self.shadowRadius = shadowRadius
    }

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(minimumScaleFactor)
            .padding(.horizontal, width == nil ? horizontalPadding : 0)
            .frame(minWidth: minWidth, maxWidth: maxWidth)
            .frame(width: width, height: height)
            .background(color, in: Capsule())
            .shadow(
                color: RallyDiscoverStyle.shadow.opacity(showsShadow ? 1 : 0),
                radius: showsShadow ? shadowRadius : 0,
                x: 0,
                y: showsShadow ? 8 : 0
            )
    }
}
