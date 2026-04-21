import Foundation
import SwiftData
import SwiftUI
import Photos
import os

/// Top-level store that:
///   1. loads the last persisted `ScanSession` on init so "View Last Results"
///      has data immediately;
///   2. runs fresh scans via `PhotoScanner` and persists the result;
///   3. exposes UI-shaped arrays (`duplicates`, `blanks`, `screenshots`) so
///      the existing detail views can drop in with a single-line change;
///   4. owns the deletion flow end-to-end: ask PhotoKit → prune SwiftData
///      → refresh the observable arrays.
@Observable
@MainActor
final class ScanStore {
    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let library: PhotoLibrary
    private let scanner: PhotoScanner

    // MARK: - Published state

    private(set) var authorizationStatus: PHAuthorizationStatus = .notDetermined
    private(set) var latestSession: ScanSession?
    /// Near-pixel-identical duplicate groups. Safe to headline as "delete the
    /// redundant copy." See `similars` for the looser review-required tier.
    private(set) var duplicates: [DuplicatePhoto] = []
    /// Same-moment / burst-alternate / reshoot groups. Visually close but not
    /// semantically duplicate — surface with explicit "review before deleting"
    /// framing, never auto-suggest.
    private(set) var similars: [DuplicatePhoto] = []
    private(set) var blanks: [SinglePhoto] = []
    private(set) var screenshots: [SinglePhoto] = []
    private(set) var scanProgress: ScanProgress = ScanProgress()
    private(set) var isScanning = false
    private(set) var isPaused = false
    private(set) var lastError: String?
    private var currentScanTask: Task<Void, Never>?

    // MARK: - Init

    init(
        modelContext: ModelContext,
        library: PhotoLibrary = PhotoLibraryService(),
        scanner: PhotoScanner? = nil
    ) {
        self.modelContext = modelContext
        self.library = library
        self.scanner = scanner ?? PhotoScanner(library: library)
        reloadFromPersisted()
    }

    // MARK: - Load persisted

    /// Pulls the latest session + assets out of SwiftData and rebuilds the
    /// UI-facing arrays. Called from init and again after every mutation.
    func reloadFromPersisted() {
        let sessionDescriptor = FetchDescriptor<ScanSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        latestSession = (try? modelContext.fetch(sessionDescriptor))?.first

        let assetDescriptor = FetchDescriptor<ScannedAsset>()
        let assets: [ScannedAsset]
        do {
            assets = try modelContext.fetch(assetDescriptor)
        } catch {
            Self.log.error("reloadFromPersisted asset fetch failed: \(error.localizedDescription, privacy: .public)")
            assets = []
        }
        Self.log.notice("reloadFromPersisted assets.count=\(assets.count)")

        screenshots = assets
            .filter(\.isScreenshot)
            .sorted { $0.createdAt > $1.createdAt }
            .map(ScanStore.makeSinglePhoto)

        blanks = assets
            .filter { $0.isBlank && !$0.isScreenshot }
            .sorted { $0.createdAt > $1.createdAt }
            .map(ScanStore.makeSinglePhoto)

        let groupDescriptor = FetchDescriptor<DuplicateGroupRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let groups = (try? modelContext.fetch(groupDescriptor)) ?? []
        Self.log.notice("reloadFromPersisted groups.count=\(groups.count) memberCounts=\(groups.map(\.members.count), privacy: .public)")
        let viable = groups.filter { $0.members.count >= 2 }
        duplicates = viable.filter { $0.kind == .exact }.map(ScanStore.makeDuplicatePhoto)
        similars = viable.filter { $0.kind == .similar }.map(ScanStore.makeDuplicatePhoto)
        Self.log.notice("reloadFromPersisted result dup:\(self.duplicates.count) similar:\(self.similars.count) shots:\(self.screenshots.count) blanks:\(self.blanks.count)")
    }

    // MARK: - Scan

    func requestAuthorization() async {
        authorizationStatus = await library.requestAuthorization()
    }

    func runScan(forceRescan: Bool) async {
        guard !isScanning else { return }
        isScanning = true
        lastError = nil
        scanProgress = ScanProgress(phase: .fetching)

        if authorizationStatus == .notDetermined {
            authorizationStatus = await library.requestAuthorization()
        }

        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            lastError = "Photo library access denied."
            isScanning = false
            return
        }

        // Force Re-Scan wipes every persisted asset + group + session up-front
        // so the UI flips to an empty state before the new scan lands. Without
        // this the user can't tell the scan actually re-ran when the photo
        // library contents happen to produce the same aggregate counts.
        if forceRescan {
            clearPersisted()
            reloadFromPersisted()
        }

        // Build the cache up-front so the scanner can work actor-isolated
        // without reaching into SwiftData.
        let cache = loadCache(forceRescan: forceRescan)

        currentScanTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.scanner.scan(
                    forceRescan: forceRescan,
                    cache: cache,
                    onProgress: { [weak self] snapshot in
                        Task { @MainActor in self?.scanProgress = snapshot }
                    },
                    onPartialResult: { [weak self] partial in
                        Task { @MainActor in self?.applyPartialResult(partial) }
                    }
                )
                try Task.checkCancellation()
                self.persist(result: result)
                self.reloadFromPersisted()
            } catch is CancellationError {
                // Cancelled — leave persisted state alone.
            } catch {
                self.lastError = error.localizedDescription
            }
            self.isScanning = false
            self.isPaused = false
            self.currentScanTask = nil
        }
        currentScanTask = task
        await task.value
    }

    // MARK: - Pause / Resume

    func pauseScan() {
        guard isScanning, !isPaused else { return }
        isPaused = true
        Task { await scanner.pause() }
    }

    func resumeScan() {
        guard isScanning, isPaused else { return }
        isPaused = false
        Task { await scanner.resume() }
    }

    /// Cancels any in-flight scan. Safe to call when nothing is running.
    func cancelScan() {
        currentScanTask?.cancel()
        currentScanTask = nil
        isScanning = false
    }

    // MARK: - Partial result handling

    /// Refresh the live UI arrays from a partial scan snapshot. Called from
    /// the scanner after every Phase-C batch so "View Results So Far" has
    /// meaningful content even before the scan completes.
    func applyPartialResult(_ partial: ScanResult) {
        let byID = Dictionary(uniqueKeysWithValues: partial.classifiedAssets.map { ($0.localIdentifier, $0) })

        duplicates = Self.buildPhotos(from: partial.exactDuplicateClusters, byID: byID)
        similars = Self.buildPhotos(from: partial.similarClusters, byID: byID)

        let screenshotsClassified = partial.classifiedAssets.filter(\.isScreenshot)
        screenshots = screenshotsClassified
            .sorted { $0.createdAt > $1.createdAt }
            .map(ScanStore.makeSinglePhoto(fromClassified:))

        let blanksClassified = partial.classifiedAssets.filter { $0.isBlank && !$0.isScreenshot }
        blanks = blanksClassified
            .sorted { $0.createdAt > $1.createdAt }
            .map(ScanStore.makeSinglePhoto(fromClassified:))
    }

    private static func buildPhotos(
        from clusters: [[String]],
        byID: [String: ClassifiedAsset]
    ) -> [DuplicatePhoto] {
        clusters.compactMap { cluster -> DuplicatePhoto? in
            let members = cluster.compactMap { byID[$0] }
            guard members.count >= 2 else { return nil }
            let primary = members.first!
            return DuplicatePhoto(
                id: UUID(),
                aspectRatio: ScanStore.aspectRatio(
                    width: primary.pixelWidth,
                    height: primary.pixelHeight
                ),
                images: members.map { classified in
                    DuplicateImage(
                        id: UUID(),
                        localIdentifier: classified.localIdentifier,
                        shade: ScanStore.displayShade(brightness: classified.brightness),
                        fileSize: classified.fileSize,
                        createdAt: classified.createdAt
                    )
                },
                isSelected: false
            )
        }
    }

    private static func makeSinglePhoto(fromClassified asset: ClassifiedAsset) -> SinglePhoto {
        SinglePhoto(
            id: UUID(),
            localIdentifier: asset.localIdentifier,
            shade: displayShade(brightness: asset.brightness),
            aspectRatio: aspectRatio(width: asset.pixelWidth, height: asset.pixelHeight),
            fileSize: asset.fileSize,
            createdAt: asset.createdAt,
            isSelected: false
        )
    }

    // MARK: - Thumbnails

    /// Async thumbnail loader used by viewer sheets and callers that only
    /// need a single image. Delegates to the underlying `PhotoLibrary` so
    /// tests can substitute a fake.
    func thumbnail(for localIdentifier: String, pixelSize: Int) async -> CGImage? {
        await library.thumbnailCGImage(localIdentifier: localIdentifier, pixelSize: pixelSize)
    }

    /// Progressive thumbnail stream for grid cells: yields the fast degraded
    /// preview first, then the high-quality upgrade. Cells consume it via
    /// `for await` so the UI shows pixels immediately and sharpens in-place.
    func thumbnailStream(for localIdentifier: String, pixelSize: Int) -> AsyncStream<CGImage> {
        library.thumbnailStream(localIdentifier: localIdentifier, pixelSize: pixelSize)
    }

    /// Hard reset of every persisted scan artifact. Used by Force Re-Scan.
    private func clearPersisted() {
        try? modelContext.delete(model: ScanSession.self)
        try? modelContext.delete(model: DuplicateGroupRecord.self)
        try? modelContext.delete(model: ScannedAsset.self)
        try? modelContext.save()
    }

    private func loadCache(forceRescan: Bool) -> [String: CachedAsset] {
        guard !forceRescan else { return [:] }
        let descriptor = FetchDescriptor<ScannedAsset>()
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        // Skip pre-pHash rows so they're re-hashed on the next scan rather
        // than reused with pHash=0 (which would make the exact-duplicate pass
        // effectively dHash-only for those assets).
        return Dictionary(uniqueKeysWithValues: rows.compactMap { row in
            guard row.pHashUnsigned != 0 else { return nil }
            return (row.localIdentifier, CachedAsset(
                localIdentifier: row.localIdentifier,
                pixelWidth: row.pixelWidth,
                pixelHeight: row.pixelHeight,
                dHash: row.dHashUnsigned,
                pHash: row.pHashUnsigned,
                brightness: row.brightness,
                variance: row.variance
            ))
        })
    }

    // MARK: - Persist

    private func persist(result: ScanResult) {
        // 1. Prune sessions + groups + assets we're replacing.
        try? modelContext.delete(model: ScanSession.self)
        try? modelContext.delete(model: DuplicateGroupRecord.self)

        // 2. Upsert scanned assets.
        let existingByID: [String: ScannedAsset] = Dictionary(
            uniqueKeysWithValues: ((try? modelContext.fetch(FetchDescriptor<ScannedAsset>())) ?? [])
                .map { ($0.localIdentifier, $0) }
        )
        let fresh = Set(result.classifiedAssets.map(\.localIdentifier))

        // Remove assets that are gone from the library.
        for (id, asset) in existingByID where !fresh.contains(id) {
            modelContext.delete(asset)
        }

        var assetByID: [String: ScannedAsset] = [:]
        for classified in result.classifiedAssets {
            let row: ScannedAsset
            if let existing = existingByID[classified.localIdentifier] {
                existing.dHashUnsigned = classified.dHash
                existing.pHashUnsigned = classified.pHash
                existing.pixelWidth = classified.pixelWidth
                existing.pixelHeight = classified.pixelHeight
                existing.fileSize = classified.fileSize
                existing.createdAt = classified.createdAt
                existing.isScreenshot = classified.isScreenshot
                existing.isBlank = classified.isBlank
                existing.brightness = classified.brightness
                existing.variance = classified.variance
                existing.burstIdentifier = classified.burstIdentifier
                existing.duplicateGroup = nil // re-assigned below
                row = existing
            } else {
                row = ScannedAsset(
                    localIdentifier: classified.localIdentifier,
                    dHash: classified.dHash,
                    pHash: classified.pHash,
                    pixelWidth: classified.pixelWidth,
                    pixelHeight: classified.pixelHeight,
                    fileSize: classified.fileSize,
                    createdAt: classified.createdAt,
                    isScreenshot: classified.isScreenshot,
                    isBlank: classified.isBlank,
                    brightness: classified.brightness,
                    variance: classified.variance,
                    burstIdentifier: classified.burstIdentifier
                )
                modelContext.insert(row)
            }
            assetByID[classified.localIdentifier] = row
        }

        // 3. Create duplicate group records for both tiers.
        for (clusters, kind) in [
            (result.exactDuplicateClusters, DuplicateGroupKind.exact),
            (result.similarClusters, DuplicateGroupKind.similar),
        ] {
            for cluster in clusters {
                let members = cluster.compactMap { assetByID[$0] }
                guard members.count >= 2 else { continue }
                let group = DuplicateGroupRecord(
                    hashBucket: members.first?.dHashUnsigned ?? 0,
                    kind: kind,
                    members: members
                )
                modelContext.insert(group)
                for m in members { m.duplicateGroup = group }
            }
        }

        // 4. Persist the session snapshot. `duplicateGroupCount` counts only
        // exact duplicates — that's what headlines as reclaimable storage.
        let session = ScanSession(
            startedAt: Date(),
            completedAt: Date(),
            totalScanned: result.classifiedAssets.count,
            duplicateGroupCount: result.exactDuplicateClusters.count,
            screenshotCount: result.classifiedAssets.count(where: \.isScreenshot),
            blankCount: result.classifiedAssets.count { $0.isBlank && !$0.isScreenshot },
            reclaimableBytes: result.reclaimableBytes
        )
        modelContext.insert(session)

        try? modelContext.save()
    }

    // MARK: - Testing hooks

    #if DEBUG
    /// Exposes `persist(result:)` to unit tests that need to seed the
    /// SwiftData store via the same path the real scan pipeline uses.
    func persistForTesting(result: ScanResult) {
        persist(result: result)
    }
    #endif

    // MARK: - Delete

    /// Delete the given assets from the Photos library (iOS prompts the user)
    /// and, on success, prune our cached rows + update the current session.
    func delete(assetIDs: [String]) async {
        guard !assetIDs.isEmpty else { return }
        let before = (duplicates.count, screenshots.count, blanks.count)
        let countsBefore = persistenceCounts()
        Self.log.notice("delete() requested ids=\(assetIDs, privacy: .public) uiBefore=dup:\(before.0)/shots:\(before.1)/blanks:\(before.2) persistBefore=assets:\(countsBefore.assets)/groups:\(countsBefore.groups)/sessions:\(countsBefore.sessions)")
        do {
            try await library.deleteAssets(localIdentifiers: assetIDs)
            let countsAfterPhotoKit = persistenceCounts()
            Self.log.notice("delete() PhotoKit ok. persistAfterPhotoKit=assets:\(countsAfterPhotoKit.assets)/groups:\(countsAfterPhotoKit.groups)/sessions:\(countsAfterPhotoKit.sessions)")
            pruneDeleted(assetIDs: Set(assetIDs))
            let countsAfterPrune = persistenceCounts()
            Self.log.notice("delete() after pruneDeleted persist=assets:\(countsAfterPrune.assets)/groups:\(countsAfterPrune.groups)/sessions:\(countsAfterPrune.sessions)")

            // The UI arrays can be populated by `applyPartialResult` during a
            // live scan before `persist` has ever run, so the persistent store
            // can legitimately be empty while the UI is full. Reloading from
            // an empty store in that case wipes the in-memory view of the
            // scan; mutate the arrays in-place instead.
            if countsAfterPrune.assets == 0 && countsAfterPrune.groups == 0 {
                Self.log.notice("delete() persistence empty → pruning in-memory arrays directly")
                pruneInMemoryArrays(assetIDs: Set(assetIDs))
            } else {
                reloadFromPersisted()
            }
            let after = (duplicates.count, screenshots.count, blanks.count)
            Self.log.notice("delete() finished uiAfter=dup:\(after.0)/shots:\(after.1)/blanks:\(after.2)")
            if before != (0, 0, 0), after == (0, 0, 0) {
                Self.log.error("⚠️ delete() wiped all categories — before=\(before.0)/\(before.1)/\(before.2) after=0/0/0 ids=\(assetIDs, privacy: .public) persistAfter=assets:\(countsAfterPrune.assets)/groups:\(countsAfterPrune.groups)")
            }
        } catch PhotoLibraryError.deletionCancelled {
            Self.log.notice("delete() cancelled by user")
        } catch {
            Self.log.error("delete() failed: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
        }
    }

    /// Counts rows directly in the persistent store (not via the cached UI
    /// arrays), so logs can distinguish "rows really were deleted" from
    /// "fetch returned empty for some other reason".
    private func persistenceCounts() -> (assets: Int, groups: Int, sessions: Int) {
        let assets = (try? modelContext.fetchCount(FetchDescriptor<ScannedAsset>())) ?? -1
        let groups = (try? modelContext.fetchCount(FetchDescriptor<DuplicateGroupRecord>())) ?? -1
        let sessions = (try? modelContext.fetchCount(FetchDescriptor<ScanSession>())) ?? -1
        return (assets, groups, sessions)
    }

    /// Fallback path when a delete happens against a UI populated only by
    /// `applyPartialResult` (no persisted rows yet). Strips deleted asset
    /// ids out of the live arrays, dropping any duplicate group that falls
    /// below 2 remaining members.
    private func pruneInMemoryArrays(assetIDs: Set<String>) {
        screenshots.removeAll { photo in
            guard let lid = photo.localIdentifier else { return false }
            return assetIDs.contains(lid)
        }
        blanks.removeAll { photo in
            guard let lid = photo.localIdentifier else { return false }
            return assetIDs.contains(lid)
        }
        duplicates = Self.prunedGroups(duplicates, assetIDs: assetIDs)
        similars = Self.prunedGroups(similars, assetIDs: assetIDs)
    }

    private static func prunedGroups(
        _ groups: [DuplicatePhoto], assetIDs: Set<String>
    ) -> [DuplicatePhoto] {
        groups.compactMap { group in
            let surviving = group.images.filter { image in
                guard let lid = image.localIdentifier else { return true }
                return !assetIDs.contains(lid)
            }
            guard surviving.count >= 2 else { return nil }
            return DuplicatePhoto(
                id: group.id,
                aspectRatio: group.aspectRatio,
                images: surviving,
                isSelected: group.isSelected
            )
        }
    }

    private static let log = Logger(subsystem: "me.kamaal.ImageCleaner", category: "ScanStore")

    private func pruneDeleted(assetIDs: Set<String>) {
        let descriptor = FetchDescriptor<ScannedAsset>()
        let rows: [ScannedAsset]
        do {
            rows = try modelContext.fetch(descriptor)
        } catch {
            Self.log.error("pruneDeleted fetch failed: \(error.localizedDescription, privacy: .public)")
            rows = []
        }
        Self.log.notice("pruneDeleted start assetIDs=\(assetIDs, privacy: .public) totalRows=\(rows.count)")

        var removedBytes: Int64 = 0
        var removedDupGroups = 0
        var removedScreenshots = 0
        var removedBlanks = 0

        for row in rows where assetIDs.contains(row.localIdentifier) {
            removedBytes += row.fileSize
            if row.isScreenshot { removedScreenshots += 1 }
            if row.isBlank && !row.isScreenshot { removedBlanks += 1 }
            modelContext.delete(row)
        }

        // Dissolve duplicate groups whose member count drops below 2.
        let groups = (try? modelContext.fetch(FetchDescriptor<DuplicateGroupRecord>())) ?? []
        Self.log.notice("pruneDeleted groups.count=\(groups.count)")
        for group in groups {
            let memberCount = group.members.count
            let remaining = group.members.filter { !assetIDs.contains($0.localIdentifier) }
            if remaining.count < 2 {
                Self.log.notice("pruneDeleted dissolve group members=\(memberCount) remaining=\(remaining.count)")
                modelContext.delete(group)
                if group.members.count >= 2 {
                    removedDupGroups += 1
                }
            }
        }

        // Update session aggregates in-place.
        if let session = latestSession {
            session.totalScanned -= assetIDs.count
            session.duplicateGroupCount -= removedDupGroups
            session.screenshotCount -= removedScreenshots
            session.blankCount -= removedBlanks
            session.reclaimableBytes = max(0, session.reclaimableBytes - removedBytes)
        }

        try? modelContext.save()
    }

    // MARK: - UI mapping

    /// Map `ScannedAsset` → the `SinglePhoto` struct the UI already binds to.
    private static func makeSinglePhoto(_ asset: ScannedAsset) -> SinglePhoto {
        SinglePhoto(
            id: UUID(),
            localIdentifier: asset.localIdentifier,
            shade: displayShade(brightness: asset.brightness),
            aspectRatio: aspectRatio(width: asset.pixelWidth, height: asset.pixelHeight),
            fileSize: asset.fileSize,
            createdAt: asset.createdAt,
            isSelected: false
        )
    }

    /// Map `DuplicateGroupRecord` → the `DuplicatePhoto` struct the UI uses.
    private static func makeDuplicatePhoto(_ group: DuplicateGroupRecord) -> DuplicatePhoto {
        let members = group.members
        let primary = members.first
        return DuplicatePhoto(
            id: UUID(),
            aspectRatio: aspectRatio(
                width: primary?.pixelWidth ?? 0,
                height: primary?.pixelHeight ?? 0
            ),
            images: members.map {
                DuplicateImage(
                    id: UUID(),
                    localIdentifier: $0.localIdentifier,
                    shade: displayShade(brightness: $0.brightness),
                    fileSize: $0.fileSize,
                    createdAt: $0.createdAt
                )
            },
            isSelected: false
        )
    }

    /// Placeholder shade from real brightness — until we wire thumbnail
    /// loading into the cells, the waterfall at least reflects actual tones.
    private static func displayShade(brightness: Double) -> Double {
        let clamped = min(max(brightness, 0.1), 0.95)
        return 1 - clamped // flip so lighter photos render with lower opacity gray
    }

    /// Clamped pixel aspect ratio (width / height) used by the Pinterest
    /// grid. Clamped so extreme panoramas don't produce absurd row heights.
    private static func aspectRatio(width: Int, height: Int) -> Double {
        guard width > 0, height > 0 else { return 1.0 }
        let raw = Double(width) / Double(height)
        return min(max(raw, 0.4), 2.5)
    }
}
