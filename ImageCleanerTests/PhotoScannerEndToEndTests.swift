import Testing
import CoreGraphics
import Photos
@testable import ImageCleaner

/// End-to-end tests for the `PhotoScanner` pipeline with a stubbed
/// `PhotoLibrary`. Proves the algorithm correctly classifies screenshots,
/// blanks, and duplicates without needing a real Photos library.
@MainActor
struct PhotoScannerEndToEndTests {
    // MARK: - Fake PhotoLibrary

    /// Sendable stub that returns pre-seeded descriptors + generated
    /// thumbnails. One fake per test so the actors don't share state.
    final class FakeLibrary: PhotoLibrary, @unchecked Sendable {
        let descriptors: [PhotoAssetDescriptor]
        let thumbnails: [String: CGImage]

        init(descriptors: [PhotoAssetDescriptor], thumbnails: [String: CGImage]) {
            self.descriptors = descriptors
            self.thumbnails = thumbnails
        }

        func authorizationStatus() async -> PHAuthorizationStatus { .authorized }
        func requestAuthorization() async -> PHAuthorizationStatus { .authorized }
        func fetchAllPhotoAssets() async -> [PhotoAssetDescriptor] { descriptors }
        func thumbnailCGImage(localIdentifier: String, pixelSize: Int) async -> CGImage? {
            thumbnails[localIdentifier]
        }
        func thumbnailStream(localIdentifier: String, pixelSize: Int) -> AsyncStream<CGImage> {
            AsyncStream { continuation in
                if let image = thumbnails[localIdentifier] {
                    continuation.yield(image)
                }
                continuation.finish()
            }
        }
        func deleteAssets(localIdentifiers: [String]) async throws {}
    }

    // MARK: - Image helpers

    /// Solid-color grayscale CGImage (width×height).
    private func solid(_ value: UInt8, size: Int = 64) -> CGImage {
        let pixels = [UInt8](repeating: value, count: size * size)
        return pixels.withUnsafeBytes { raw in
            let provider = CGDataProvider(data: Data(raw) as CFData)!
            return CGImage(
                width: size, height: size,
                bitsPerComponent: 8, bitsPerPixel: 8,
                bytesPerRow: size,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider, decode: nil,
                shouldInterpolate: false, intent: .defaultIntent
            )!
        }
    }

    /// 4x4-block checker — yields a stable dHash.
    private func checker(size: Int = 64, cell: Int = 8) -> CGImage {
        var pixels = [UInt8](repeating: 0, count: size * size)
        for y in 0..<size {
            for x in 0..<size {
                let on = ((x / cell) + (y / cell)) % 2 == 0
                pixels[y * size + x] = on ? 255 : 0
            }
        }
        return pixels.withUnsafeBytes { raw in
            let provider = CGDataProvider(data: Data(raw) as CFData)!
            return CGImage(
                width: size, height: size,
                bitsPerComponent: 8, bitsPerPixel: 8,
                bytesPerRow: size,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider, decode: nil,
                shouldInterpolate: false, intent: .defaultIntent
            )!
        }
    }

    private func descriptor(
        id: String,
        width: Int = 64,
        height: Int = 64,
        isScreenshot: Bool = false
    ) -> PhotoAssetDescriptor {
        PhotoAssetDescriptor(
            localIdentifier: id,
            pixelWidth: width,
            pixelHeight: height,
            createdAt: .now,
            mediaSubtypes: isScreenshot ? PHAssetMediaSubtype.photoScreenshot.rawValue : 0,
            estimatedFileSize: 500_000
        )
    }

    // MARK: - Screenshot detection

    @Test func scannerFlagsScreenshotsByMediaSubtype() async throws {
        let thumbs: [String: CGImage] = [
            "unique": checker(),
            "shot": checker(),
        ]
        let descs = [
            descriptor(id: "unique", width: 100, height: 150),
            descriptor(id: "shot", width: 390, height: 844, isScreenshot: true),
        ]
        let scanner = PhotoScanner(library: FakeLibrary(descriptors: descs, thumbnails: thumbs))
        let result = try await scanner.scan(forceRescan: true) { _ in }

        let screenshots = result.classifiedAssets.filter(\.isScreenshot)
        #expect(screenshots.count == 1)
        #expect(screenshots.first?.localIdentifier == "shot")
    }

    // MARK: - Blank detection

    @Test func scannerFlagsBlankPhotosByBrightness() async throws {
        let thumbs: [String: CGImage] = [
            "black": solid(0),
            "photo": checker(),
        ]
        let descs = [
            descriptor(id: "black", width: 1024, height: 1024),
            descriptor(id: "photo", width: 500, height: 500),
        ]
        let scanner = PhotoScanner(library: FakeLibrary(descriptors: descs, thumbnails: thumbs))
        let result = try await scanner.scan(forceRescan: true) { _ in }

        let blanks = result.classifiedAssets.filter { $0.isBlank && !$0.isScreenshot }
        #expect(blanks.count == 1)
        #expect(blanks.first?.localIdentifier == "black")
    }

    // MARK: - Duplicate clustering

    @Test func scannerClustersDuplicatesByHashProximity() async throws {
        let sharedPattern = checker(size: 64, cell: 8)
        let thumbs: [String: CGImage] = [
            "dup_a": sharedPattern,
            "dup_b": sharedPattern,
            "different": solid(128),
        ]
        let descs = [
            descriptor(id: "dup_a", width: 500, height: 500),
            descriptor(id: "dup_b", width: 500, height: 500),
            descriptor(id: "different", width: 500, height: 500),
        ]
        let scanner = PhotoScanner(library: FakeLibrary(descriptors: descs, thumbnails: thumbs))
        let result = try await scanner.scan(forceRescan: true) { _ in }

        #expect(result.duplicateClusters.count == 1)
        let cluster = try #require(result.duplicateClusters.first)
        #expect(cluster.sorted() == ["dup_a", "dup_b"])
    }

    // MARK: - Full pipeline

    @Test func scannerProducesAllThreeCategoriesInOneRun() async throws {
        // Use distinct checker patterns so dHashes differ and don't cross-cluster.
        // `normal` is a non-uniform image so it doesn't get flagged as blank.
        let dup = checker(size: 64, cell: 8)
        let thumbs: [String: CGImage] = [
            "dup1": dup,
            "dup2": dup,
            "shot": checker(size: 64, cell: 4),
            "blank": solid(0),
            "normal": checker(size: 64, cell: 16),
        ]
        let descs = [
            descriptor(id: "dup1", width: 500, height: 500),
            descriptor(id: "dup2", width: 500, height: 500),
            descriptor(id: "shot", width: 390, height: 844, isScreenshot: true),
            descriptor(id: "blank", width: 1024, height: 1024),
            descriptor(id: "normal", width: 800, height: 600),
        ]
        let scanner = PhotoScanner(library: FakeLibrary(descriptors: descs, thumbnails: thumbs))

        let progressLog = LockedProgress()
        let result = try await scanner.scan(forceRescan: true) { progress in
            progressLog.record(progress)
        }

        #expect(result.duplicateClusters.count == 1)
        #expect(result.classifiedAssets.filter(\.isScreenshot).count == 1)
        #expect(result.classifiedAssets.filter { $0.isBlank && !$0.isScreenshot }.count == 1)
        let last = progressLog.last()
        #expect(last?.phase == .done)
        #expect(last?.total == 5)
    }

    // MARK: - Cache reuse

    @Test func scannerSkipsPixelWorkWhenCachedAndDimensionsMatch() async throws {
        let thumbs: [String: CGImage] = ["photo": checker()]
        let descs = [descriptor(id: "photo", width: 500, height: 500)]
        let scanner = PhotoScanner(library: FakeLibrary(descriptors: descs, thumbnails: thumbs))

        let cache: [String: CachedAsset] = [
            "photo": CachedAsset(
                localIdentifier: "photo",
                pixelWidth: 500,
                pixelHeight: 500,
                dHash: 0xABCD,
                brightness: 0.5,
                variance: 0.1
            ),
        ]
        let result = try await scanner.scan(forceRescan: false, cache: cache) { _ in }
        let asset = try #require(result.classifiedAssets.first)
        #expect(asset.wasCached == true)
        #expect(asset.dHash == 0xABCD) // reused cached hash
    }

    @Test func forceRescanIgnoresCache() async throws {
        let thumbs: [String: CGImage] = ["photo": checker()]
        let descs = [descriptor(id: "photo", width: 500, height: 500)]
        let scanner = PhotoScanner(library: FakeLibrary(descriptors: descs, thumbnails: thumbs))

        let cache: [String: CachedAsset] = [
            "photo": CachedAsset(
                localIdentifier: "photo",
                pixelWidth: 500,
                pixelHeight: 500,
                dHash: 0xDEAD, // deliberately wrong to prove recomputation
                brightness: 0.5,
                variance: 0.1
            ),
        ]
        let result = try await scanner.scan(forceRescan: true, cache: cache) { _ in }
        let asset = try #require(result.classifiedAssets.first)
        #expect(asset.wasCached == false)
        #expect(asset.dHash != 0xDEAD) // ignored the poisoned cache entry
    }

    // MARK: - Progress phases

    @Test func scannerEmitsAllExpectedProgressPhases() async throws {
        let thumbs = ["a": checker()]
        let descs = [descriptor(id: "a")]
        let scanner = PhotoScanner(library: FakeLibrary(descriptors: descs, thumbnails: thumbs))

        let phases = LockedPhases()
        _ = try await scanner.scan(forceRescan: true) { progress in
            phases.append(progress.phase)
        }

        let seen = Set(phases.all())
        #expect(seen.contains(.fetching))
        #expect(seen.contains(.classifying))
        #expect(seen.contains(.pixelAnalyzing))
        #expect(seen.contains(.clustering))
        #expect(seen.contains(.done))
    }
}

/// Tiny thread-safe helpers so progress callbacks (which run on an actor)
/// can record into collections the tests can inspect.
private final class LockedPhases: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [ScanProgress.Phase] = []

    func append(_ phase: ScanProgress.Phase) {
        lock.lock(); defer { lock.unlock() }
        storage.append(phase)
    }

    func all() -> [ScanProgress.Phase] {
        lock.lock(); defer { lock.unlock() }
        return storage
    }
}

private final class LockedProgress: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [ScanProgress] = []

    func record(_ progress: ScanProgress) {
        lock.lock(); defer { lock.unlock() }
        storage.append(progress)
    }

    func last() -> ScanProgress? {
        lock.lock(); defer { lock.unlock() }
        return storage.last
    }
}
