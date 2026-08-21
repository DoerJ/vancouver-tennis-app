import SwiftUI

struct ProfileFallbackAvatarView: View {
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)

            ZStack {
                Circle()
                    .fill(Color(red: 145.0 / 255.0, green: 168.0 / 255.0, blue: 87.0 / 255.0))

                Circle()
                    .fill(.white)
                    .frame(width: side * 0.28, height: side * 0.28)
                    .position(x: side * 0.49, y: side * 0.41)

                RoundedRectangle(cornerRadius: side * 0.125, style: .continuous)
                    .fill(Color(red: 51.0 / 255.0, green: 92.0 / 255.0, blue: 31.0 / 255.0))
                    .frame(width: side * 0.55, height: side * 0.3)
                    .position(x: side * 0.5, y: side * 0.75)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
