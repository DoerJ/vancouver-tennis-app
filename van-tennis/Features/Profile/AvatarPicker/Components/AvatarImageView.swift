import SwiftUI
import UIKit

struct AvatarImageView: View {
    let image: UIImage?
    let size: CGFloat

    init(
        image: UIImage?,
        size: CGFloat
    ) {
        self.image = image
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 217.0 / 255.0, green: 217.0 / 255.0, blue: 217.0 / 255.0).opacity(0.2))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFill()
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle(), style: FillStyle(eoFill: false, antialiased: true))
        .compositingGroup()
    }
}
