import Foundation
import UIKit

@MainActor
final class AvatarPickerViewModel: ObservableObject {
    @Published private(set) var avatarOptions: [ProfileAvatarOption] = []
    @Published private(set) var isLoadingAvatarOptions = false
    @Published private(set) var isSavingAvatar = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var selectedAvatarURL: URL?
    @Published private var avatarImagesByCacheKey: [String: UIImage] = [:]

    private let profileAvatarStorageService = ProfileAvatarStorageService()
    private static let imageCache = NSCache<NSString, UIImage>()
    private var hasSelectedAvatar = false

    func loadAvatarOptions() async {
        isLoadingAvatarOptions = true
        errorMessage = nil

        do {
            avatarOptions = try await profileAvatarStorageService.fetchProfileAvatars()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingAvatarOptions = false
    }

    func syncSelectedAvatarIfNeeded(currentAvatarURL: URL?) {
        guard !hasSelectedAvatar else {
            return
        }

        selectedAvatarURL = currentAvatarURL
        hasSelectedAvatar = true
    }

    func selectAvatar(_ avatar: ProfileAvatarOption) {
        selectedAvatarURL = avatar.url
        hasSelectedAvatar = true
        errorMessage = nil
    }

    func canSaveAvatar(currentAvatarURL: URL?) -> Bool {
        guard hasSelectedAvatar else {
            return false
        }

        return selectedAvatarURL != currentAvatarURL
    }

    func image(
        for url: URL,
        size: CGFloat,
        displayScale: CGFloat
    ) -> UIImage? {
        avatarImagesByCacheKey[cacheKey(for: url, size: size, displayScale: displayScale)]
    }

    // Avatars are loaded from supabase storage bucket for the first time user launches the app
    // Then gets cached in memory
    func loadImage(
        for url: URL,
        size: CGFloat,
        displayScale: CGFloat
    ) async {
        let cacheKey = cacheKey(for: url, size: size, displayScale: displayScale)

        if let cachedImage = avatarImagesByCacheKey[cacheKey] {
            avatarImagesByCacheKey[cacheKey] = cachedImage
            return
        }

        if let cachedImage = Self.imageCache.object(forKey: cacheKey as NSString) {
            avatarImagesByCacheKey[cacheKey] = cachedImage
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let downsampledImage = ImageDownsamplingHelper.downsampleImage(
                data: data,
                targetPixelSize: ImageDownsamplingHelper.targetPixelSize(size: size, displayScale: displayScale)
            ) else {
                return
            }

            Self.imageCache.setObject(downsampledImage, forKey: cacheKey as NSString)
            avatarImagesByCacheKey[cacheKey] = downsampledImage
        } catch {
            return
        }
    }

    func saveSelectedAvatar(
        currentAvatarURL: URL?,
        appState: AppState
    ) async -> Bool {
        guard hasSelectedAvatar,
              selectedAvatarURL != currentAvatarURL else {
            return false
        }

        isSavingAvatar = true
        errorMessage = nil

        defer {
            isSavingAvatar = false
        }

        do {
            try await appState.updateProfile(avatarURL: .some(selectedAvatarURL))

            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // The mapping key for retrieving avatar images from in-memory cache
    private func cacheKey(
        for url: URL,
        size: CGFloat,
        displayScale: CGFloat
    ) -> String {
        "\(url.absoluteString)-\(ImageDownsamplingHelper.targetPixelSize(size: size, displayScale: displayScale))"
    }
}
