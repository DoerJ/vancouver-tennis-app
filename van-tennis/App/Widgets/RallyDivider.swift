import SwiftUI

struct RallyDivider: View {
    let width: CGFloat?
    let horizontalPadding: CGFloat
    let leadingPadding: CGFloat

    init(
        width: CGFloat? = nil,
        horizontalPadding: CGFloat = 0,
        leadingPadding: CGFloat = 0
    ) {
        self.width = width
        self.horizontalPadding = horizontalPadding
        self.leadingPadding = leadingPadding
    }

    var body: some View {
        Rectangle()
            .fill(Color.black.opacity(0.10))
            .frame(width: width, height: 1)
            .frame(maxWidth: .infinity, alignment: width == nil ? .leading : .center)
            .padding(.horizontal, horizontalPadding)
            .padding(.leading, leadingPadding)
    }
}
