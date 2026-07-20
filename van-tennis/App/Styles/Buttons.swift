import SwiftUI

struct RallyPrimaryActionButtonStyle: ButtonStyle {
    let isEnabled: Bool
    let showsShadow: Bool

    init(isEnabled: Bool = true, showsShadow: Bool = false) {
        self.isEnabled = isEnabled
        self.showsShadow = showsShadow
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(minHeight: 52)
            .padding(.horizontal, 18)
            .background(
                RallyDiscoverStyle.primaryGreen.opacity(buttonOpacity(isPressed: configuration.isPressed)),
                in: Capsule()
            )
            .shadow(color: RallyDiscoverStyle.shadow.opacity(shadowOpacity), radius: 18, x: 0, y: 8)
            .shadow(color: Color.black.opacity(secondaryShadowOpacity), radius: 6, x: 0, y: 2)
    }

    private var shadowOpacity: Double {
        isEnabled && showsShadow ? 0.95 : 0
    }

    private var secondaryShadowOpacity: Double {
        isEnabled && showsShadow ? 0.05 : 0
    }

    private func buttonOpacity(isPressed: Bool) -> Double {
        guard isEnabled else {
            return 0.45
        }

        return isPressed ? 0.78 : 1
    }
}

struct RallySurfaceActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.black)
            .frame(minHeight: 52)
            .padding(.horizontal, 18)
            .background(Color(red: 0.97, green: 0.97, blue: 0.96).opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(Capsule())
            .shadow(color: RallyDiscoverStyle.shadow.opacity(0.95), radius: 18, x: 0, y: 8)
            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

struct RallyDestructiveActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(minHeight: 52)
            .padding(.horizontal, 18)
            .background(Color(red: 0.98, green: 0.28, blue: 0.13).opacity(configuration.isPressed ? 0.82 : 1), in: Capsule())
    }
}

struct RallyCompactPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 140, height: 40)
            .background(RallyDiscoverStyle.primaryGreen.opacity(configuration.isPressed ? 0.78 : 1), in: Capsule())
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

struct RallyCompactMutedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 140, height: 40)
            .background(Color.black.opacity(configuration.isPressed ? 0.40 : 0.50), in: Capsule())
    }
}

struct RallyFilterPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 71, height: 22)
            .background(RallyDiscoverStyle.accentGreen.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(Capsule())
            .shadow(color: RallyDiscoverStyle.shadow, radius: 9, x: 0, y: 8)
    }
}
