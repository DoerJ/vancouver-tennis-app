import SwiftUI

struct RallyToast: View {
    let iconName: String
    let backgroundColor: Color
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)

            Text(message)
                .font(.rally(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundColor, in: Capsule())
        .shadow(color: RallyDiscoverStyle.shadow.opacity(0.45), radius: 14, x: 0, y: 6)
    }
}
