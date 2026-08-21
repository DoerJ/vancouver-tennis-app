import SwiftUI

struct ProfileAvatarImageView: View {
    let url: URL?
    let size: CGFloat

    @Environment(\.displayScale) private var displayScale
    @StateObject private var viewModel = ProfileAvatarImageViewModel()

    var body: some View {
        Group {
            if url == nil {
                ProfileFallbackAvatarView()
                    .frame(width: size, height: size)
            } else {
                remoteAvatar
            }
        }
        .task(id: imageTaskID) {
            await viewModel.loadImage(
                url: url,
                size: size,
                displayScale: displayScale
            )
        }
    }

    private var remoteAvatar: some View {
        ZStack {
            placeholder

            if let image = viewModel.image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFill()
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle(), style: FillStyle(eoFill: false, antialiased: true))
    }

    private var placeholder: some View {
        Circle()
            .fill(Color(red: 217.0 / 255.0, green: 217.0 / 255.0, blue: 217.0 / 255.0).opacity(0.2))
    }

    private var imageTaskID: String {
        "\(url?.absoluteString ?? "nil")-\(ImageDownsamplingHelper.targetPixelSize(size: size, displayScale: displayScale))"
    }
}
