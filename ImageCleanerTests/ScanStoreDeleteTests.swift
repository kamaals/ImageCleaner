import Testing
import SwiftData
import Photos
@testable import ImageCleaner

/// Regression tests for `ScanStore.delete(assetIDs:)` — specifically the
/// scenario reported in user testing: a 7-photo duplicate group, delete one,
/// expect the other 6 (and every other group / screenshot / blank) to remain.
@MainActor
struct ScanStoreDeleteTests {
    // MARK: - Fakes

    final class StubLibrary: PhotoLibrary, @unchecked Sendable {
        var deletedIDs: [String] = []
        var deletionShouldThrow: Error?

        func authorizationStatus() async -> PHAuthorizationStatus { .authorized }
        func requestAuthorization() async -> PHAuthorizationStatus { .authorized }
        func fetchAllPhotoAssets() async -> [PhotoAssetDescriptor] { [] }
        func thumbnailCGImage(localIdentifier: String, pixelSize: Int) async -> CGImage? { nil }
        func thumbnailStream(localIdentifier: String, pixelSize: Int) -> AsyncStream<CGImage> {
            AsyncStream { $0.finish() }
        }
        func deleteAssets(localIdentifiers: [String]) async throws {
            if let err = deletionShouldThrow { throw err }
            deletedIDs.append(contentsOf: localIdentifiers)
        }
    }

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([ScannedAsset.self, DuplicateGroupRecord.self, ScanSession.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    /// Seeds the context with: one big duplicate group of `bigGroupSize`,
    /// plus `extraGroups` more pair-groups, plus `screenshots` screenshots,
    /// plus `blanks` blank photos. Returns the localIdentifier of the first
    /// member of the big group (our "tap one to delete" target).
    @discardableResult
    private func seed(
        context: ModelContext,
        bigGroupSize: Int = 7,
        extraGroups: Int = 4,
        screenshots: Int = 3,
        blanks: Int = 2
    ) -> String {
        // Big group
        let bigMembers: [ScannedAsset] = (0..<bigGroupSize).map { i in
            ScannedAsset(
                localIdentifier: "big-\(i)",
                dHash: 0xAAAA,
                pixelWidth: 500, pixelHeight: 500,
                fileSize: 1_000_000,
                brightness: 0.5, variance: 0.1
            )
        }
        for m in bigMembers { context.insert(m) }
        let bigGroup = DuplicateGroupRecord(hashBucket: 0xAAAA, members: bigMembers)
        context.insert(bigGroup)

        // Extra pair-groups
        for g in 0..<extraGroups {
            let members: [ScannedAsset] = (0..<2).map { i in
                ScannedAsset(
                    localIdentifier: "extra-\(g)-\(i)",
                    dHash: UInt64(0xBBBB + g),
                    pixelWidth: 500, pixelHeight: 500,
                    fileSize: 800_000,
                    brightness: 0.5, variance: 0.1
                )
            }
            for m in members { context.insert(m) }
            let group = DuplicateGroupRecord(hashBucket: UInt64(0xBBBB + g), members: members)
            context.insert(group)
        }

        // Screenshots
        for i in 0..<screenshots {
            let s = ScannedAsset(
                localIdentifier: "shot-\(i)",
                dHash: UInt64(0xCCCC + i),
                pixelWidth: 390, pixelHeight: 844,
                fileSize: 500_000,
                isScreenshot: true,
                brightness: 0.7, variance: 0.2
            )
            context.insert(s)
        }

        // Blanks
        for i in 0..<blanks {
            let b = ScannedAsset(
                localIdentifier: "blank-\(i)",
                dHash: UInt64(0xDDDD + i),
                pixelWidth: 1024, pixelHeight: 1024,
                fileSize: 200_000,
                isBlank: true,
                brightness: 0.02, variance: 0.001
            )
            context.insert(b)
        }

        // Session
        let session = ScanSession(
            totalScanned: bigGroupSize + extraGroups * 2 + screenshots + blanks,
            duplicateGroupCount: 1 + extraGroups,
            screenshotCount: screenshots,
            blankCount: blanks,
            reclaimableBytes: 10_000_000
        )
        context.insert(session)

        try? context.save()
        return "big-0"
    }

    // MARK: - Regression: the reported bug

    @Test
    func deletingOneFromSevenKeepsSixInThatGroupAndAllOtherData() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let targetID = seed(context: context)

        let library = StubLibrary()
        let store = ScanStore(modelContext: context, library: library)
        store.reloadFromPersisted()

        // Pre-delete expectations
        #expect(store.duplicates.count == 5) // 1 big + 4 extra
        #expect(store.screenshots.count == 3)
        #expect(store.blanks.count == 2)
        let bigGroupBefore = try #require(
            store.duplicates.first { $0.images.count == 7 }
        )
        #expect(bigGroupBefore.images.count == 7)

        // Act — same call the sheet's X-button makes
        await store.delete(assetIDs: [targetID])

        // The user reported: blank screen, no grid, all counts zero.
        // Expected: the big group shrinks 7→6, the other 4 groups stay,
        // and screenshots / blanks are untouched.
        #expect(library.deletedIDs == [targetID])
        #expect(store.duplicates.count == 5, "other groups should not disappear")
        #expect(store.screenshots.count == 3, "screenshots should not disappear")
        #expect(store.blanks.count == 2, "blanks should not disappear")

        let bigGroupAfter = try #require(
            store.duplicates.first { $0.images.count >= 6 }
        )
        #expect(bigGroupAfter.images.count == 6)
        #expect(!bigGroupAfter.images.contains { $0.localIdentifier == targetID })
    }

    @Test
    func deletingOneFromPairDissolvesGroupButKeepsEverythingElse() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        _ = seed(context: context, bigGroupSize: 2, extraGroups: 3, screenshots: 2, blanks: 1)

        let library = StubLibrary()
        let store = ScanStore(modelContext: context, library: library)
        store.reloadFromPersisted()

        #expect(store.duplicates.count == 4) // 1 big(2) + 3 extra
        await store.delete(assetIDs: ["big-0"])

        #expect(store.duplicates.count == 3, "only the dissolved pair-group is gone")
        #expect(store.screenshots.count == 2)
        #expect(store.blanks.count == 1)
    }

    /// Same scenario as the 7→6 test, but the data is populated through the
    /// real `persist(result:)` code path — with `asset.duplicateGroup = group`
    /// set explicitly on both sides of the relationship, the way the live app
    /// does. Screenshot from the user shows this flow wiping all data after a
    /// single delete, so the test has to use the same path to reproduce it.
    @Test
    func deletingOneThroughRealPersistFlowKeepsOtherGroupsAndCategories() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let library = StubLibrary()

        // Build a ScanResult that matches the user's setup: one big group
        // of 7 dupes, 4 other pair-groups, 3 screenshots, 2 blanks.
        var classified: [ClassifiedAsset] = []
        var clusters: [[String]] = []

        let bigIDs = (0..<7).map { "big-\($0)" }
        for id in bigIDs {
            classified.append(fakeClassified(id: id, fileSize: 1_000_000))
        }
        clusters.append(bigIDs)

        for g in 0..<4 {
            let pair = (0..<2).map { "extra-\(g)-\($0)" }
            for id in pair {
                classified.append(fakeClassified(id: id, fileSize: 800_000, dimensionSeed: g + 1))
            }
            clusters.append(pair)
        }

        for i in 0..<3 {
            classified.append(fakeClassified(id: "shot-\(i)", fileSize: 500_000, isScreenshot: true, dimensionSeed: 10 + i))
        }
        for i in 0..<2 {
            classified.append(fakeClassified(id: "blank-\(i)", fileSize: 200_000, isBlank: true, dimensionSeed: 20 + i))
        }

        let result = ScanResult(
            classifiedAssets: classified,
            exactDuplicateClusters: clusters,
            similarClusters: []
        )

        // Drive persistence via the public ScanStore API so the ModelContext
        // sees exactly what the real scan pipeline produces.
        let store = ScanStore(modelContext: context, library: library)
        store.applyPartialResult(result) // primes screenshots/blanks UI arrays
        callPersist(store: store, result: result)
        store.reloadFromPersisted()

        #expect(store.duplicates.count == 5, "seed: 1 big + 4 pairs")
        #expect(store.screenshots.count == 3)
        #expect(store.blanks.count == 2)

        // Act
        await store.delete(assetIDs: ["big-0"])

        // If the bug reproduces here, these will fail.
        #expect(store.duplicates.count == 5, "other groups must survive a single delete")
        #expect(store.screenshots.count == 3)
        #expect(store.blanks.count == 2)
    }

    private func fakeClassified(
        id: String,
        fileSize: Int64,
        isScreenshot: Bool = false,
        isBlank: Bool = false,
        dimensionSeed: Int = 0
    ) -> ClassifiedAsset {
        ClassifiedAsset(
            localIdentifier: id,
            pixelWidth: 500 + dimensionSeed,
            pixelHeight: 500 + dimensionSeed,
            createdAt: .now,
            fileSize: fileSize,
            isScreenshot: isScreenshot,
            isBlank: isBlank,
            dHash: 0xAAAA,
            pHash: 0xBBBB,
            brightness: isBlank ? 0.02 : 0.5,
            variance: isBlank ? 0.001 : 0.1,
            burstIdentifier: nil,
            wasCached: false
        )
    }

    /// `persist` is private; call via @testable bridge.
    private func callPersist(store: ScanStore, result: ScanResult) {
        store.persistForTesting(result: result)
    }

    /// The exact scenario the user hit: UI arrays populated by
    /// `applyPartialResult` during an in-progress scan, SwiftData still empty
    /// because `persist(result:)` hasn't run yet. Deleting one asset must NOT
    /// wipe the rest of the live view.
    @Test
    func deleteDuringPartialScanPrunesInMemoryWithoutWiping() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let library = StubLibrary()
        let store = ScanStore(modelContext: context, library: library)

        // Simulate "scan in progress": apply a partial result with one 7-photo
        // duplicate group, 3 screenshots, 2 blanks. `persist` never runs.
        var classified: [ClassifiedAsset] = []
        let bigIDs = (0..<7).map { "big-\($0)" }
        for id in bigIDs {
            classified.append(fakeClassified(id: id, fileSize: 1_000_000))
        }
        for g in 0..<3 { // extra pair-groups
            for i in 0..<2 {
                classified.append(fakeClassified(
                    id: "extra-\(g)-\(i)",
                    fileSize: 900_000,
                    dimensionSeed: g + 1
                ))
            }
        }
        for i in 0..<3 {
            classified.append(fakeClassified(
                id: "shot-\(i)", fileSize: 500_000, isScreenshot: true, dimensionSeed: 10 + i
            ))
        }
        for i in 0..<2 {
            classified.append(fakeClassified(
                id: "blank-\(i)", fileSize: 200_000, isBlank: true, dimensionSeed: 20 + i
            ))
        }
        let clusters = [bigIDs] + (0..<3).map { g in (0..<2).map { "extra-\(g)-\($0)" } }
        store.applyPartialResult(ScanResult(
            classifiedAssets: classified,
            exactDuplicateClusters: clusters,
            similarClusters: []
        ))

        #expect(store.duplicates.count == 4)
        #expect(store.screenshots.count == 3)
        #expect(store.blanks.count == 2)

        // Act — delete one photo from the 7-member group, as the sheet X does.
        await store.delete(assetIDs: ["big-0"])

        // Must NOT wipe. Big group shrinks to 6, other groups + categories
        // remain exactly as shown in the UI.
        #expect(store.duplicates.count == 4, "partial-scan delete must not drop the other groups")
        #expect(store.screenshots.count == 3)
        #expect(store.blanks.count == 2)
        let bigGroupAfter = try #require(store.duplicates.first { $0.images.count >= 6 })
        #expect(bigGroupAfter.images.count == 6)
        #expect(!bigGroupAfter.images.contains { $0.localIdentifier == "big-0" })
    }

    @Test
    func deletionCancelledLeavesEverythingIntact() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        _ = seed(context: context)

        let library = StubLibrary()
        library.deletionShouldThrow = PhotoLibraryError.deletionCancelled
        let store = ScanStore(modelContext: context, library: library)
        store.reloadFromPersisted()

        await store.delete(assetIDs: ["big-0"])

        #expect(store.duplicates.count == 5)
        #expect(store.screenshots.count == 3)
        #expect(store.blanks.count == 2)
        let bigGroup = try #require(store.duplicates.first { $0.images.count == 7 })
        #expect(bigGroup.images.count == 7)
    }
}
