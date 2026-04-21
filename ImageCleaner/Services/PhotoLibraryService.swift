import Foundation
import Photos
import UIKit

/// Sendable descriptor for a PhotoKit asset. Decouples the scanner from
/// `PHAsset` so everything downstream of the service is easily Sendable-safe.
struct PhotoAssetDescriptor: Sendable, Hashable {
    let localIdentifier: String
    let pixelWidth: Int
    let pixelHeight: Int
    let createdAt: Date
    let mediaSubtypes: UInt   // raw bits of PHAssetMediaSubtype
    let estimatedFileSize: Int64
    /// Non-nil when this asset is part of a burst sequence; same value across
    /// all burst siblings. Two assets sharing this id are *not* duplicates —
    /// they're consecutive shutter presses (blink variants, etc.).
    let burstIdentifier: String?

    var isScreenshot: Bool {
        PHAssetMediaSubtype(rawValue: mediaSubtypes).contains(.photoScreenshot)
    }
}

enum PhotoLibraryError: Error, Equatable {
    case accessDenied
    case assetNotFound
    case deletionCancelled
    case thumbnailUnavailable
}

/// Abstraction over PhotoKit so scanner + store can be unit-tested with a fake.
protocol PhotoLibrary: Sendable {
    func authorizationStatus() async -> PHAuthorizationStatus
    func requestAuthorization() async -> PHAuthorizationStatus
    func fetchAllPhotoAssets() async -> [PhotoAssetDescriptor]
    /// Returns a single thumbnail suitable for the scanner's pixel analysis
    /// (dHash/brightness). Uses opportunistic delivery and accepts the first
    /// usable image — even a degraded preview has plenty of pixels for a dHash.
    func thumbnailCGImage(localIdentifier: String, pixelSize: Int) async -> CGImage?
    /// Streams thumbnails for UI: yields the fast degraded preview first
    /// (instant feedback), then the high-quality upgrade. The stream finishes
    /// after the last delivery so the caller can `for await` the whole sequence.
    func thumbnailStream(localIdentifier: String, pixelSize: Int) -> AsyncStream<CGImage>
    func deleteAssets(localIdentifiers: [String]) async throws
}

/// Production `PhotoLibrary` backed by `PHPhotoLibrary` + `PHImageManager`.
/// `final` + stored-property-free so it's naturally `Sendable`.
final class PhotoLibraryService: PhotoLibrary {
    private let imageManager: PHImageManager

    init(imageManager: PHImageManager = .default()) {
        self.imageManager = imageManager
    }

    // MARK: - Authorization

    func authorizationStatus() async -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    // MARK: - Fetch

    func fetchAllPhotoAssets() async -> [PhotoAssetDescriptor] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let result = PHAsset.fetchAssets(with: options)
        var descriptors: [PhotoAssetDescriptor] = []
        descriptors.reserveCapacity(result.count)

        result.enumerateObjects { asset, _, _ in
            descriptors.append(
                PhotoAssetDescriptor(
                    localIdentifier: asset.localIdentifier,
                    pixelWidth: asset.pixelWidth,
                    pixelHeight: asset.pixelHeight,
                    createdAt: asset.creationDate ?? .distantPast,
                    mediaSubtypes: asset.mediaSubtypes.rawValue,
                    estimatedFileSize: Self.estimateFileSize(asset),
                    burstIdentifier: asset.burstIdentifier
                )
            )
        }
        return descriptors
    }

    /// Rough byte estimate based on pixel count. Exact byte size requires a
    /// full resource fetch which is expensive; the estimate is fine for
    /// "reclaimable storage" display.
    private static func estimateFileSize(_ asset: PHAsset) -> Int64 {
        let pixels = Int64(asset.pixelWidth) * Int64(asset.pixelHeight)
        // Empirically ~0.3 bytes/pixel for typical HEIC/JPEG photos.
        return Int64(Double(pixels) * 0.3)
    }

    // MARK: - Thumbnail

    func thumbnailCGImage(localIdentifier: String, pixelSize: Int) async -> CGImage? {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = result.firstObject else { return nil }

        let options = PHImageRequestOptions()
        options.resizeMode = .exact
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        options.version = .current

        // Target size: snap to a minimum of 128 — very small target sizes can
        // return `PHPhotosError.notAvailable` (code 3303) on simulator assets
        // that lack a pre-cached fast-format thumbnail at that exact size.
        let effectiveSize = CGFloat(max(pixelSize, 128))
        let targetSize = CGSize(width: effectiveSize, height: effectiveSize)

        return await withCheckedContinuation { continuation in
            var didResume = false
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                guard !didResume else { return }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if (info?[PHImageCancelledKey] as? Bool) == true {
                    didResume = true
                    continuation.resume(returning: nil)
                    return
                }
                if let image {
                    // Accept any image we get — even a degraded opportunistic
                    // preview is enough pixels for dHash / brightness analysis.
                    didResume = true
                    continuation.resume(returning: image.cgImage)
                    return
                }
                if info?[PHImageErrorKey] != nil, !isDegraded {
                    didResume = true
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func thumbnailStream(localIdentifier: String, pixelSize: Int) -> AsyncStream<CGImage> {
        AsyncStream { continuation in
            let result = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
            guard let asset = result.firstObject else {
                continuation.finish()
                return
            }

            let options = PHImageRequestOptions()
            options.resizeMode = .exact
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            options.version = .current

            let effectiveSize = CGFloat(max(pixelSize, 128))
            let targetSize = CGSize(width: effectiveSize, height: effectiveSize)

            let requestID = imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                if let image = image?.cgImage {
                    continuation.yield(image)
                }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let cancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                // Opportunistic delivery sends degraded first, then the final
                // high-quality upgrade with `isDegraded == false`. Finish only
                // after the non-degraded delivery (or on cancel/error).
                if !isDegraded || cancelled {
                    continuation.finish()
                }
            }

            continuation.onTermination = { @Sendable _ in
                PHImageManager.default().cancelImageRequest(requestID)
            }
        }
    }

    // MARK: - Delete

    func deleteAssets(localIdentifiers: [String]) async throws {
        guard !localIdentifiers.isEmpty else { return }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil)
        guard fetchResult.count > 0 else { throw PhotoLibraryError.assetNotFound }

        var assets: [PHAsset] = []
        assets.reserveCapacity(fetchResult.count)
        fetchResult.enumerateObjects { asset, _, _ in assets.append(asset) }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
            }
        } catch let error as NSError where error.domain == "PHPhotosErrorDomain" && error.code == 3072 {
            // User dismissed the confirmation — treat as cancel, not failure.
            throw PhotoLibraryError.deletionCancelled
        }
    }
}
