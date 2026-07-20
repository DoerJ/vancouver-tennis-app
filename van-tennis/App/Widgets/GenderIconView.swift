import SwiftUI

struct GenderIconView: View {
    let gender: Gender?
    let size: CGFloat?

    init(_ gender: Gender?, size: CGFloat? = nil) {
        self.gender = gender
        self.size = size
    }

    var body: some View {
        Image(GenderDisplayHelper.iconName(for: gender))
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}
