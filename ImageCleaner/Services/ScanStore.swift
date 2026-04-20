import Foundation
import SwiftData
import SwiftUI
import Photos

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
    private(set) var duplicates: [DuplicatePhoto] = []
    private(set) var blanks: [SinglePhoto] = []
    private(set) var screenshots: [SinglePhoto] = []
    private(set) var scanProgress: ScanProgress = ScanProgress()
    private(set) var isScanning = false
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
        let assets = (try? modelContext.fetch(assetDescriptor)) ?? []

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
        duplicates = groups
            .filter { $0.members.count >= 2 }
            .map(ScanStore.makeDuplicatePhoto)
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
                    cache: cache
                ) { [weak self] snapshot in
                    Task { @MainActor in self?.scanProgress = snapshot }
                }
                try Task.checkCancellation()
                self.persist(result: result)
                self.reloadFromPersisted()
            } catch is CancellationError {
                // Cancelled — leave persisted state alone.
            } catch {
                self.lastError = error.localizedDescription
            }
            self.isScanning = false
            self.currentScanTask = nil
        }
        currentScanTask = task
        await task.value
    }

    /// Cancels any in-flight scan. Safe to call when nothing is running.
    func cancelScan() {
        currentScanTask?.cancel()
        currentScanTask = nil
        isScanning = false
    }

    // MARK: - Thumbnails

    /// Async thumbnail loader used by cells + viewer sheets. Delegates to the
    /// underlying `PhotoLibrary` so tests can substitute a fake.
    func thumbnail(for localIdentifier: String, pixelSize: Int) async -> CGImage? {
        await library.thumbnailCGImage(localIdentifier: localIdentifier, pixelSize: pixelSize)
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
        return Dictionary(uniqueKeysWithValues: rows.map { row in
            (row.localIdentifier, CachedAsset(
                localIdentifier: row.localIdentifier,
                pixelWidth: row.pixelWidth,
                pixelHeight: row.pixelHeight,
                dHash: row.dHashUnsigned,
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
                existing.pixelWidth = classified.pixelWidth
                existing.pixelHeight = classified.pixelHeight
                existing.fileSize = classified.fileSize
                existing.createdAt = classified.createdAt
                existing.isScreenshot = classified.isScreenshot
                existing.isBlank = classified.isBlank
                existing.brightness = classified.brightness
                existing.variance = classified.variance
                existing.duplicateGroup = nil // re-assigned below
                row = existing
            } else {
                row = ScannedAsset(
                    localIdentifier: classified.localIdentifier,
                    dHash: classified.dHash,
                    pixelWidth: classified.pixelWidth,
                    pixelHeight: classified.pixelHeight,
                    fileSize: classified.fileSize,
                    createdAt: classified.createdAt,
                    isScreenshot: classified.isScreenshot,
                    isBlank: classified.isBlank,
                    brightness: classified.brightness,
                    variance: classified.variance
                )
                modelContext.insert(row)
            }
            assetByID[classified.localIdentifier] = row
        }

        // 3. Create duplicate group records linking members.
        for cluster in result.duplicateClusters {
            let members = cluster.compactMap { assetByID[$0] }
            guard members.count >= 2 else { continue }
            let group = DuplicateGroupRecord(
                hashBucket: members.first?.dHashUnsigned ?? 0,
                members: members
            )
            modelContext.insert(group)
            for m in members { m.duplicateGroup = group }
        }

        // 4. Persist the session snapshot.
        let session = ScanSession(
            startedAt: Date(),
            completedAt: Date(),
            totalScanned: result.classifiedAssets.count,
            duplicateGroupCount: result.duplicateClusters.count,
            screenshotCount: result.classifiedAssets.count(where: \.isScreenshot),
            blankCount: result.classifiedAssets.count { $0.isBlank && !$0.isScreenshot },
            reclaimableBytes: result.reclaimableBytes
        )
        modelContext.insert(session)

        try? modelContext.save()
    }

    // MARK: - Delete

    /// Delete the given assets from the Photos library (iOS prompts the user)
    /// and, on success, prune our cached rows + update the current session.
    func delete(assetIDs: [String]) async {
        guard !assetIDs.isEmpty else { return }
        do {
            try await library.deleteAssets(localIdentifiers: assetIDs)
            pruneDeleted(assetIDs: Set(assetIDs))
            reloadFromPersisted()
        } catch PhotoLibraryError.deletionCancelled {
            // no-op: user backed out.
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func pruneDeleted(assetIDs: Set<String>) {
        let descriptor = FetchDescriptor<ScannedAsset>()
        let rows = (try? modelContext.fetch(descriptor)) ?? []

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
        for group in groups {
            let remaining = group.members.filter { !assetIDs.contains($0.localIdentifier) }
            if remaining.count < 2 {
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
