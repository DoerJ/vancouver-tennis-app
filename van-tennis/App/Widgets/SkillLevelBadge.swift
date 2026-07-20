import SwiftUI

struct SkillLevelBadge: View {
    let text: String
    let color: Color
    let width: CGFloat?
    let minWidth: CGFloat?
    let showsShadow: Bool
    let shadowOpacity: Double
    let shadowRadius: CGFloat

    init(
        _ skillLevel: SkillLevel?,
        fallbackText: String = AppContent.string("events.host.skillNotSet"),
        width: CGFloat? = nil,
        minWidth: CGFloat? = 71,
        showsShadow: Bool = false,
        shadowOpacity: Double = 1,
        shadowRadius: CGFloat = 18
    ) {
        self.text = skillLevel?.rawValue ?? fallbackText
        self.color = Constants.SkillLevelStyle.badgeColor(for: skillLevel)
        self.width = width
        self.minWidth = minWidth
        self.showsShadow = showsShadow
        self.shadowOpacity = shadowOpacity
        self.shadowRadius = shadowRadius
    }

    init(
        _ skillLevel: SkillLevel,
        width: CGFloat? = nil,
        minWidth: CGFloat? = 71,
        showsShadow: Bool = false,
        shadowOpacity: Double = 1,
        shadowRadius: CGFloat = 18
    ) {
        self.init(
            Optional(skillLevel),
            width: width,
            minWidth: minWidth,
            showsShadow: showsShadow,
            shadowOpacity: shadowOpacity,
            shadowRadius: shadowRadius
        )
    }

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(minWidth: minWidth)
            .padding(.horizontal, width == nil ? 8 : 0)
            .frame(width: width, height: 22)
            .background(color, in: Capsule())
            .shadow(
                color: RallyDiscoverStyle.shadow.opacity(showsShadow ? shadowOpacity : 0),
                radius: showsShadow ? shadowRadius : 0,
                x: 0,
                y: showsShadow ? 8 : 0
            )
    }
}
