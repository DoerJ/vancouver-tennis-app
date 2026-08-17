import SwiftUI

extension View {
    func rallyLoadingStatusStyle() -> some View {
        font(.rally(size: 15, weight: .medium))
            .foregroundStyle(Color.black.opacity(0.5))
            .tint(Color.black.opacity(0.5))
    }
}
