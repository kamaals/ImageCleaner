import Foundation
import CoreGraphics

/// Snapshot of progress during a scan run. Emitted by `PhotoScanner.scan` on
/// every batch boundary and bridged back to the main-actor ViewModel.
struct ScanProgress: Sendable, Equatable {
    enum Phase: Sendable, Equatable {
        case fetching
        case classifying
        case pixelAnalyzing
        case clustering
        case done
    }

    var phase: Phase = .fetching
    var total: Int = 0
    var processed: Int = 0
    var screenshotsFound: Int = 0
    var blanksFound: Int = 0
    var duplicateGroupsFound: Int = 0
}

/// Classification of a single asset as produced by the scanner. The `dHash`,
/// `brightness`, and `variance` are left at `nil` when we reused a cached entry
/// with no pixel work — the caller writes them back only when they're fresh.
struct ClassifiedAsset: Sendable {
    let localIdentifier: String
    let pixelWidth: Int
    let pixelHeight: Int
    let createdAt: Date
    let fileSize: Int64
    let isScreenshot: Bool
    let isBlank: Bool
    let dHash: UInt64
    let brightness: Double
    let variance: Double
    let wasCached: Bool
}

/// Result of a completed scan. `duplicateClusters` is a list of id groups,
/// each ≥ 2 items, that cluster by dHash Hamming distance.
struct ScanResult: Sendable {
    var classifiedAssets: [ClassifiedAsset]
    var duplicateClusters: [[String]]

    /// Total bytes recoverable if user drops every screenshot, every blank,
    /// and keeps only the largest-filesize member of each duplicate cluster.
    var reclaimableBytes: Int64 {
        let byID = Dictionary(uniqueKeysWithValues: classifiedAssets.map { ($0.localIdentifier, $0) })
        let screenshotBytes = classifiedAssets.filter(\.isScreenshot).reduce(0) { $0 + $1.fileSize }
        let blankBytes = classifiedAssets
            .filter { $0.isBlank && !$0.isScreenshot }
            .reduce(0) { $0 + $1.fileSize }
        let dupBytes: Int64 = duplicateClusters.reduce(0) { running, cluster in
            let members = cluster.compactMap { byID[$0] }
            guard !members.isEmpty else { return running }
            let largest = members.max(by: { $0.fileSize < $1.fileSize })?.fileSize ?? 0
            let sum = members.reduce(0) { $0 + $1.fileSize }
            return running + (sum - largest)
        }
        return screenshotBytes + blankBytes + dupBytes
    }
}

/// Cached classification carried over from a previous scan session. Passed
/// into the scanner so pixel analysis can be skipped for unchanged photos.
struct CachedAsset: Sendable {
    let localIdentifier: String
    let pixelWidth: Int
    let pixelHeight: Int
    let dHash: UInt64
    let brightness: Double
    let variance: Double
}

/// Four-phase photo-library scanner. Isolated as an actor so all scan state
/// lives off the main actor; progress bridges back to the caller via a
/// `@Sendable` closure.
actor PhotoScanner {
    private let library: PhotoLibrary
    private let thumbnailPixelSize: Int
    private let concurrency: Int
    private let clusterThreshold: Int
    private let blankBrightnessCeiling: Double
    private let blankVarianceCeiling: Double
    private let uniformVarianceCeiling: Double

    init(
        library: PhotoLibrary,
        thumbnailPixelSize: Int = 64,
        concurrency: Int = 8,
        clusterThreshold: Int = 5,
        blankBrightnessCeiling: Double = 0.05,
        blankVarianceCeiling: Double = 0.01,
        uniformVarianceCeiling: Double = 0.0005
    ) {
        self.library = library
        self.thumbnailPixelSize = thumbnailPixelSize
        self.concurrency = concurrency
        self.clusterThreshold = clusterThreshold
        self.blankBrightnessCeiling = blankBrightnessCeiling
        self.blankVarianceCeiling = blankVarianceCeiling
        self.uniformVarianceCeiling = uniformVarianceCeiling
    }

    func scan(
        forceRescan: Bool,
        cache: [String: CachedAsset] = [:],
        onProgress: @Sendable @escaping (ScanProgress) -> Void
    ) async throws -> ScanResult {
        // Phase A — fetch ---------------------------------------------------
        var progress = ScanProgress(phase: .fetching)
        onProgress(progress)

        let descriptors = await library.fetchAllPhotoAssets()
        progress.total = descriptors.count
        progress.phase = .classifying
        onProgress(progress)
        try Task.checkCancellation()

        // Phase B — metadata classification --------------------------------
        var screenshotCount = 0
        for descriptor in descriptors where descriptor.isScreenshot {
            screenshotCount += 1
        }
        progress.screenshotsFound = screenshotCount
        onProgress(progress)

        // Phase C — pixel classification (with cache) ----------------------
        progress.phase = .pixelAnalyzing
        var classified: [ClassifiedAsset] = []
        classified.reserveCapacity(descriptors.count)

        let batchSize = 50
        let batches = stride(from: 0, to: descriptors.count, by: batchSize).map { start -> ArraySlice<PhotoAssetDescriptor> in
            descriptors[start..<min(start + batchSize, descriptors.count)]
        }

        for batch in batches {
            try Task.checkCancellation()
            let batchResults = try await classifyBatch(
                batch,
                forceRescan: forceRescan,
                cache: cache
            )
            classified.append(contentsOf: batchResults)
            progress.processed = classified.count
            progress.blanksFound = classified.reduce(0) { $0 + ($1.isBlank ? 1 : 0) }
            onProgress(progress)
        }

        // Phase D — cluster -------------------------------------------------
        progress.phase = .clustering
        onProgress(progress)

        let clusters = cluster(classified)
        progress.duplicateGroupsFound = clusters.count
        progress.phase = .done
        onProgress(progress)

        return ScanResult(classifiedAssets: classified, duplicateClusters: clusters)
    }

    // MARK: - Phase C helpers

    private func classifyBatch(
        _ batch: ArraySlice<PhotoAssetDescriptor>,
        forceRescan: Bool,
        cache: [String: CachedAsset]
    ) async throws -> [ClassifiedAsset] {
        try await withThrowingTaskGroup(of: ClassifiedAsset?.self) { group in
            for descriptor in batch {
                group.addTask { [self] in
                    try Task.checkCancellation()
                    return await classify(descriptor, forceRescan: forceRescan, cache: cache)
                }
            }
            var results: [ClassifiedAsset] = []
            for try await result in group {
                if let result { results.append(result) }
            }
            return results
        }
    }

    private func classify(
        _ descriptor: PhotoAssetDescriptor,
        forceRescan: Bool,
        cache: [String: CachedAsset]
    ) async -> ClassifiedAsset? {
        // Cache hit: reuse dHash + brightness + variance iff dimensions match.
        if !forceRescan,
           let cached = cache[descriptor.localIdentifier],
           cached.pixelWidth == descriptor.pixelWidth,
           cached.pixelHeight == descriptor.pixelHeight {
            return ClassifiedAsset(
                localIdentifier: descriptor.localIdentifier,
                pixelWidth: descriptor.pixelWidth,
                pixelHeight: descriptor.pixelHeight,
                createdAt: descriptor.createdAt,
                fileSize: descriptor.estimatedFileSize,
                isScreenshot: descriptor.isScreenshot,
                isBlank: Self.isBlank(
                    brightness: cached.brightness,
                    variance: cached.variance,
                    blankBrightnessCeiling: blankBrightnessCeiling,
                    blankVarianceCeiling: blankVarianceCeiling,
                    uniformVarianceCeiling: uniformVarianceCeiling
                ),
                dHash: cached.dHash,
                brightness: cached.brightness,
                variance: cached.variance,
                wasCached: true
            )
        }

        guard let cgImage = await library.thumbnailCGImage(
            localIdentifier: descriptor.localIdentifier,
            pixelSize: thumbnailPixelSize
        ) else {
            // iCloud-only asset or thumbnail unavailable: classify from
            // metadata only so we at least track the screenshot subtype.
            return ClassifiedAsset(
                localIdentifier: descriptor.localIdentifier,
                pixelWidth: descriptor.pixelWidth,
                pixelHeight: descriptor.pixelHeight,
                createdAt: descriptor.createdAt,
                fileSize: descriptor.estimatedFileSize,
                isScreenshot: descriptor.isScreenshot,
                isBlank: false,
                dHash: 0,
                brightness: 0,
                variance: 0,
                wasCached: false
            )
        }

        let dHash = ImageAnalysis.dHash(cgImage)
        let (brightness, variance) = ImageAnalysis.brightnessAndVariance(cgImage)
        return ClassifiedAsset(
            localIdentifier: descriptor.localIdentifier,
            pixelWidth: descriptor.pixelWidth,
            pixelHeight: descriptor.pixelHeight,
            createdAt: descriptor.createdAt,
            fileSize: descriptor.estimatedFileSize,
            isScreenshot: descriptor.isScreenshot,
            isBlank: Self.isBlank(
                brightness: brightness,
                variance: variance,
                blankBrightnessCeiling: blankBrightnessCeiling,
                blankVarianceCeiling: blankVarianceCeiling,
                uniformVarianceCeiling: uniformVarianceCeiling
            ),
            dHash: dHash,
            brightness: brightness,
            variance: variance,
            wasCached: false
        )
    }

    private static func isBlank(
        brightness: Double,
        variance: Double,
        blankBrightnessCeiling: Double,
        blankVarianceCeiling: Double,
        uniformVarianceCeiling: Double
    ) -> Bool {
        (brightness < blankBrightnessCeiling && variance < blankVarianceCeiling)
            || variance < uniformVarianceCeiling
    }

    // MARK: - Phase D

    private func cluster(_ assets: [ClassifiedAsset]) -> [[String]] {
        // Bucket by dimensions — duplicates must have identical pixel size
        // (the experiments converge on this; it also keeps clusters tight).
        let buckets = Dictionary(grouping: assets.filter { $0.dHash != 0 }) {
            "\($0.pixelWidth)x\($0.pixelHeight)"
        }

        var clusters: [[String]] = []
        for bucket in buckets.values where bucket.count >= 2 {
            let pairs = bucket.map { (id: $0.localIdentifier, hash: $0.dHash) }
            let groups = ImageAnalysis.cluster(hashes: pairs, threshold: clusterThreshold)
            clusters.append(contentsOf: groups)
        }
        return clusters
    }
}
