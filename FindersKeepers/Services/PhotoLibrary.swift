import Photos
import UIKit

/// Every call into Apple's Photos framework lives here.
enum PhotoLibrary {
    static let keptAlbumTitle = "Finders Keepers"

    // MARK: Permission

    static var access: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    static func requestAccess() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    // MARK: Finding screenshots

    /// Every screenshot on the phone, oldest first. Hidden photos are never included.
    static func screenshots() -> [PHAsset] {
        let oldestFirst = PHFetchOptions()
        oldestFirst.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        var found: [PHAsset] = []

        // Photos keeps its own Screenshots album. Reading that is the cheapest way in.
        let albums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumScreenshots, options: nil)
        if let album = albums.firstObject {
            PHAsset.fetchAssets(in: album, options: oldestFirst).enumerateObjects { asset, _, _ in
                if asset.mediaType == .image { found.append(asset) }
            }
        }
        // If that album is missing or empty, check each photo's own "this is a screenshot" flag.
        if found.isEmpty {
            PHAsset.fetchAssets(with: .image, options: oldestFirst).enumerateObjects { asset, _, _ in
                if asset.mediaSubtypes.contains(.photoScreenshot) { found.append(asset) }
            }
        }
        #if DEBUG
        let known = Set(found.map(\.localIdentifier))
        let fixtures = DebugLaunch.fixtureIDs.filter { !known.contains($0) }
        if !fixtures.isEmpty {
            PHAsset.fetchAssets(withLocalIdentifiers: fixtures, options: nil).enumerateObjects { asset, _, _ in found.append(asset) }
            found.sort { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
        }
        #endif
        return found
    }

    // MARK: Loading images

    /// Loads one image at roughly the size asked for. Returns nil if Photos cannot supply it.
    static func image(for asset: PHAsset, targetSize: CGSize, contentMode: PHImageContentMode) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true        // lets iCloud Photos fetch the original if needed

            var hasAnswered = false                       // a continuation must be resumed exactly once
            PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: contentMode, options: options) { image, info in
                let isPreview = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !isPreview, !hasAnswered else { return }
                hasAnswered = true
                continuation.resume(returning: image)
            }
        }
    }

    /// The full-size pixels, for text recognition.
    static func fullSizeImage(for asset: PHAsset) async -> CGImage? {
        await image(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default)?.cgImage
    }

    // MARK: Changing the library

    /// Moves screenshots to Recently Deleted. iOS shows one confirmation for the whole batch.
    /// Returns false if the person taps "Don't Allow".
    static func delete(_ assets: [PHAsset]) async -> Bool {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            }
            return true
        } catch {
            return false
        }
    }

    /// Adds a screenshot to, or removes it from, the "Finders Keepers" album. The photo itself is untouched.
    static func setKept(_ isKept: Bool, _ asset: PHAsset) async {
        guard let album = await keptAlbum(createIfMissing: isKept) else { return }
        try? await PHPhotoLibrary.shared().performChanges {
            let change = PHAssetCollectionChangeRequest(for: album)
            if isKept {
                change?.addAssets([asset] as NSArray)
            } else {
                change?.removeAssets([asset] as NSArray)
            }
        }
    }

    /// The Photos identifiers of everything in the "Finders Keepers" album.
    static func keptAlbumIDs() -> Set<String> {
        guard let album = findKeptAlbum() else { return [] }
        var ids: Set<String> = []
        PHAsset.fetchAssets(in: album, options: nil).enumerateObjects { asset, _, _ in
            ids.insert(asset.localIdentifier)
        }
        return ids
    }

    private static func keptAlbum(createIfMissing: Bool) async -> PHAssetCollection? {
        if let existing = findKeptAlbum() { return existing }
        guard createIfMissing else { return nil }
        try? await PHPhotoLibrary.shared().performChanges {
            _ = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: keptAlbumTitle)
        }
        return findKeptAlbum()
    }

    private static func findKeptAlbum() -> PHAssetCollection? {
        var match: PHAssetCollection?
        PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil).enumerateObjects { album, _, stop in
            if album.localizedTitle == keptAlbumTitle {
                match = album
                stop.pointee = true
            }
        }
        return match
    }
}

/// Tells the app when the photo library changes, for example when a new screenshot is taken.
final class LibraryObserver: NSObject, PHPhotoLibraryChangeObserver {
    private let onChange: @MainActor @Sendable () -> Void

    init(onChange: @escaping @MainActor @Sendable () -> Void) {
        self.onChange = onChange
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        let onChange = onChange
        Task { @MainActor in onChange() }
    }
}
