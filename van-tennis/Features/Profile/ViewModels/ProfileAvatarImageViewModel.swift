import Foundation
import UIKit

@MainActor
final class ProfileAvatarImageViewModel: ObservableObject {
    @Published private(set) var image: UIImage?

    private var currentCacheKey: String?
    private static let imageCache = NSCache<NSString, UIImage>()

    func loadImage(
        url: URL?,
        size: CGFloat,
        displayScale: CGFloat
    ) async {
        guard let url else {
            currentCacheKey = nil
            image = nil
            return
        }

        let targetPixelSize = ImageDownsamplingHelper.targetPixelSize(
            size: size,
            displayScale: displayScale
        )
        let cacheKey = "\(url.absoluteString)-\(targetPixelSize)"

        if currentCacheKey == cacheKey,
           image != nil {
            return
        }

        currentCacheKey = cacheKey

        if let cachedImage = Self.imageCache.object(forKey: cacheKey as NSString) {
            image = cachedImage
            return
        }

        image = nil

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let downsampledImage = ImageDownsamplingHelper.downsampleImage(
                data: data,
                targetPixelSize: targetPixelSize
            ) else {
                return
            }

            Self.imageCache.setObject(downsampledImage, forKey: cacheKey as NSString)

            guard currentCacheKey == cacheKey else {
                return
            }

            image = downsampledImage
        } catch {
            return
        }
    }
}
