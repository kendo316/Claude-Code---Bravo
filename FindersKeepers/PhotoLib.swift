import Photos
import UIKit
import EventKit

private final class Box<T>: @unchecked Sendable { var v: T?; init() {} }

enum PhotoLib {
    static let albumName = "Finders Keepers"

    /// Loads one image. Pass PHImageManagerMaximumSize + .default for OCR.
    static func image(for a: PHAsset, size: CGSize,
                      mode: PHImageContentMode = .aspectFit,
                      exact: Bool = false) async -> UIImage? {
        await withCheckedContinuation { cont in
            let o = PHImageRequestOptions()
            o.deliveryMode = .highQualityFormat
            o.isNetworkAccessAllowed = true
            o.resizeMode = exact ? .exact : .fast
            PHImageManager.default().requestImage(for: a, targetSize: size, contentMode: mode, options: o) { img, info in
                if (info?[PHImageResultIsDegradedKey] as? Bool) == true { return }
                cont.resume(returning: img)
            }
        }
    }

    // MARK: Kept album

    static func keptAlbum() async -> PHAssetCollection? {
        let f = PHFetchOptions()
        f.predicate = NSPredicate(format: "title = %@", albumName)
        if let c = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: f).firstObject {
            return c
        }
        let box = Box<String>()
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let req = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
                box.v = req.placeholderForCreatedAssetCollection.localIdentifier
            }
        } catch { return nil }
        guard let id = box.v else { return nil }
        return PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil).firstObject
    }

    static func setKept(_ a: PHAsset, _ on: Bool) async {
        guard let col = await keptAlbum() else { return }
        try? await PHPhotoLibrary.shared().performChanges {
            guard let req = PHAssetCollectionChangeRequest(for: col) else { return }
            if on { req.addAssets([a] as NSArray) } else { req.removeAssets([a] as NSArray) }
        }
    }

    // MARK: Delete (iOS shows ONE confirmation for the whole batch)

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
}

// MARK: - Calendar (one tap, unlike the web version)

enum Cal {
    static func add(title: String, date: Date, notes: String) async -> Bool {
        let store = EKEventStore()
        guard (try? await store.requestWriteOnlyAccessToEvents()) == true else { return false }
        let e = EKEvent(eventStore: store)
        e.title = title
        e.notes = notes
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        if c.hour == 0 && c.minute == 0 {
            e.isAllDay = true
            e.startDate = date
            e.endDate = date
        } else {
            e.startDate = date
            e.endDate = date.addingTimeInterval(3600)
        }
        e.calendar = store.defaultCalendarForNewEvents
        do { try store.save(e, span: .thisEvent); return true } catch { return false }
    }
}
