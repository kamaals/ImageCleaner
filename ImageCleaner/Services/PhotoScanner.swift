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
/// `pHash`, `brightness`, and `variance` are left at `0` when we reused a
/// cached entry with no pixel work — the caller writes them back only when
/// they're fresh.
struct ClassifiedAsset: Sendable {
    let localIdentifier: String
    let pixelWidth: Int
    let pixelHeight: Int
    let createdAt: Date
    let fileSize: Int64
    let isScreenshot: Bool
    let isBlank: Bool
    let dHash: UInt64
    let pHash: UInt64
    let brightness: Double
    let variance: Double
    /// Shared across all photos in the same burst sequence. Burst siblings
    /// are excluded from duplicate clustering — they're deliberate variants,
    /// not duplicates.
    let burstIdentifier: String?
    let wasCached: Bool
}

/// Result of a completed scan.
///
/// `exactDuplicateClusters` are near-pixel-identical matches (tight dHash +
/// pHash thresholds, same pixel dimensions, burst siblings excluded). Safe
/// to surface as "delete this, it's the same photo twice."
///
/// `similarClusters` are visually-close matches (looser threshold) — burst
/// alternates, same-moment captures, same-scene reshots. Require human review
/// before deletion. Assets that appear in an exact cluster are *not* repeated
/// in a similar cluster.
struct ScanResult: Sendable {
    var classifiedAssets: [ClassifiedAsset]
    var exactDuplicateClusters: [[String]]
    var similarClusters: [[String]]

    /// Bytes recoverable across screenshots, blanks, and exact duplicates
    /// (keeping one per cluster). Similar clusters are *not* counted — we
    /// don't want the reclaimable-space headline implying users should
    /// mass-delete the "review required" pile.
    var reclaimableBytes: Int64 {
        let byID = Dictionary(uniqueKeysWithValues: classifiedAssets.map { ($0.localIdentifier, $0) })
        let screenshotBytes = classifiedAssets.filter(\.isScreenshot).reduce(0) { $0 + $1.fileSize }
        let blankBytes = classifiedAssets
            .filter { $0.isBlank && !$0.isScreenshot }
            .reduce(0) { $0 + $1.fileSize }
        let dupBytes: Int64 = exactDuplicateClusters.reduce(0) { running, cluster in
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
    let pHash: UInt64
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
    /// Tight Hamming distance for **exact** duplicate clustering — pairs must
    /// agree on both dHash and pHash within this budget. Research on dHash
    /// puts the exact/similar boundary at 1–2 bits; we use 2 for dHash and a
    /// looser pHash budget (the two hashes together act as a joint gate).
    private let exactDHashThreshold: Int
    private let exactPHashThreshold: Int
    /// Looser Hamming budget for **similar** clustering — same-moment shots,
    /// burst alternates, reshots. Surfaced in a separate UI with human-review
    /// framing.
    private let similarDHashThreshold: Int
    private let blankBrightnessCeiling: Double
    private let blankVarianceCeiling: Double
    private let uniformVarianceCeiling: Double

    /// Pause/resume state. `pauseContinuation` is only non-nil while the scan
    /// loop is parked inside `awaitResumeIfPaused()`.
    private(set) var isPaused = false
    private var pauseContinuation: CheckedContinuation<Void, Never>?

    init(
        library: PhotoLibrary,
        thumbnailPixelSize: Int = 128,
        concurrency: Int = 8,
        exactDHashThreshold: Int = 2,
        exactPHashThreshold: Int = 4,
        similarDHashThreshold: Int = 5,
        blankBrightnessCeiling: Double = 0.05,
        blankVarianceCeiling: Double = 0.01,
        uniformVarianceCeiling: Double = 0.0005
    ) {
        self.library = library
        self.thumbnailPixelSize = thumbnailPixelSize
        self.concurrency = concurrency
        self.exactDHashThreshold = exactDHashThreshold
        self.exactPHashThreshold = exactPHashThreshold
        self.similarDHashThreshold = similarDHashThreshold
        self.blankBrightnessCeiling = blankBrightnessCeiling
        self.blankVarianceCeiling = blankVarianceCeiling
        self.uniformVarianceCeiling = uniformVarianceCeiling
    }

    // MARK: - Pause / Resume

    func pause() {
        isPaused = true
    }

    /// Resume the scan if currently paused. Safe to call when not paused.
    func resume() {
        isPaused = false
        let continuation = pauseContinuation
        pauseContinuation = nil
        continuation?.resume()
    }

    /// Parks the scan loop while `isPaused` is true. Called at each Phase-C
    /// batch boundary. Returns immediately when not paused.
    private func awaitResumeIfPaused() async {
        guard isPaused else { return }
        await withCheckedContinuation { continuation in
            // Re-check now that we're actor-isolated inside the continuation
            // closure; if resume() fired between the outer guard and here, we
            // must resume immediately rather than trap the continuation.
            if !isPaused {
                continuation.resume()
                return
            }
            self.pauseContinuation = continuation
        }
    }

    // MARK: - Scan

    func scan(
        forceRescan: Bool,
        cache: [String: CachedAsset] = [:],
        onProgress: @Sendable @escaping (ScanProgress) -> Void,
        onPartialResult: @Sendable @escaping (ScanResult) -> Void = { _ in }
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
            await awaitResumeIfPaused()
            try Task.checkCancellation()

            let batchResults = try await classifyBatch(
                batch,
                forceRescan: forceRescan,
                cache: cache
            )
            classified.append(contentsOf: batchResults)
            progress.processed = classified.count
            progress.blanksFound = classified.reduce(0) { $0 + ($1.isBlank ? 1 : 0) }
            // Live exact-duplicate count — cheap because `cluster` bucket-
            // filters by dimensions first so typical libraries yield small
            // buckets.
            let live = cluster(classified)
            progress.duplicateGroupsFound = live.exact.count
            onProgress(progress)
            // Provide a partial `ScanResult` snapshot so the store can refresh
            // the UI arrays without waiting for the final completion — this
            // is what makes "View Results So Far" meaningful while paused.
            onPartialResult(ScanResult(
                classifiedAssets: classified,
                exactDuplicateClusters: live.exact,
                similarClusters: live.similar
            ))
        }

        // Phase D — cluster -------------------------------------------------
        progress.phase = .clustering
        onProgress(progress)

        let final = cluster(classified)
        progress.duplicateGroupsFound = final.exact.count
        progress.phase = .done
        onProgress(progress)

        return ScanResult(
            classifiedAssets: classified,
            exactDuplicateClusters: final.exact,
            similarClusters: final.similar
        )
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
        // Cache hit: reuse dHash + pHash + brightness + variance iff
        // dimensions match.
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
                pHash: cached.pHash,
                brightness: cached.brightness,
                variance: cached.variance,
                burstIdentifier: descriptor.burstIdentifier,
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
                pHash: 0,
                brightness: 0,
                variance: 0,
                burstIdentifier: descriptor.burstIdentifier,
                wasCached: false
            )
        }

        let dHash = ImageAnalysis.dHash(cgImage)
        let pHash = ImageAnalysis.pHash(cgImage)
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
            pHash: pHash,
            brightness: brightness,
            variance: variance,
            burstIdentifier: descriptor.burstIdentifier,
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

    /// Clusters classified assets into two disjoint tiers:
    /// - `exact`: dHash ≤ `exactDHashThreshold` *and* pHash ≤
    ///   `exactPHashThreshold` *and* `createdAt` matches to the second. Burst
    ///   siblings are excluded. The timestamp gate is the decisive signal for
    ///   "same source photo, re-imported/re-encoded" vs "consecutive shutter
    ///   presses of a similar scene" — the hashes alone can't distinguish
    ///   same-scene-different-moment shots when framing dominates the hash.
    /// - `similar`: dHash ≤ `similarDHashThreshold`, among assets that didn't
    ///   already land in an exact cluster. Burst siblings are allowed here so
    ///   users can still see them as "related" for review.
    private func cluster(_ assets: [ClassifiedAsset]) -> (exact: [[String]], similar: [[String]]) {
        let eligible = assets.filter { $0.dHash != 0 }
        let buckets = Dictionary(grouping: eligible) {
            "\($0.pixelWidth)x\($0.pixelHeight)"
        }
        let byID = Dictionary(uniqueKeysWithValues: assets.map { ($0.localIdentifier, $0) })

        var exactClusters: [[String]] = []
        var similarClusters: [[String]] = []
        var usedInExact = Set<String>()

        for bucket in buckets.values where bucket.count >= 2 {
            let exact = clusterStrict(
                bucket: bucket,
                byID: byID,
                dHashBudget: exactDHashThreshold,
                pHashBudget: exactPHashThreshold,
                excludeSameBurst: true,
                requireSameCreationSecond: true
            )
            exactClusters.append(contentsOf: exact)
            for group in exact { usedInExact.formUnion(group) }

            let remaining = bucket.filter { !usedInExact.contains($0.localIdentifier) }
            guard remaining.count >= 2 else { continue }
            let similar = clusterStrict(
                bucket: remaining,
                byID: byID,
                dHashBudget: similarDHashThreshold,
                pHashBudget: nil,
                excludeSameBurst: false,
                requireSameCreationSecond: false
            )
            similarClusters.append(contentsOf: similar)
        }
        return (exactClusters, similarClusters)
    }

    /// Greedy clustering inside a single dimension bucket, applying every
    /// constraint required by the caller's tier. Seeds the first un-clustered
    /// asset and pulls in every candidate that satisfies all gates.
    private func clusterStrict(
        bucket: [ClassifiedAsset],
        byID: [String: ClassifiedAsset],
        dHashBudget: Int,
        pHashBudget: Int?,
        excludeSameBurst: Bool,
        requireSameCreationSecond: Bool
    ) -> [[String]] {
        var remaining = bucket
        var groups: [[String]] = []

        while let seed = remaining.first {
            remaining.removeFirst()
            var cluster: [String] = [seed.localIdentifier]
            remaining.removeAll { candidate in
                if ImageAnalysis.hamming(seed.dHash, candidate.dHash) > dHashBudget {
                    return false
                }
                if let pBudget = pHashBudget,
                   seed.pHash != 0, candidate.pHash != 0,
                   ImageAnalysis.hamming(seed.pHash, candidate.pHash) > pBudget {
                    return false
                }
                if excludeSameBurst,
                   let seedBurst = seed.burstIdentifier,
                   let candBurst = candidate.burstIdentifier,
                   seedBurst == candBurst {
                    return false
                }
                if requireSameCreationSecond,
                   Int(seed.createdAt.timeIntervalSince1970)
                   != Int(candidate.createdAt.timeIntervalSince1970) {
                    return false
                }
                cluster.append(candidate.localIdentifier)
                return true
            }
            if cluster.count >= 2 { groups.append(cluster) }
        }
        return groups
    }
}
