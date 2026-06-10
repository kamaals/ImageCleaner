import Testing
import SwiftData
import Photos
@testable import ImageCleaner

@MainActor
struct ScanStoreAuthorizationTests {
    /// Configurable PhotoLibrary fake for authorization-flow tests. `current`
    /// is the synchronous status; `requestAuthorization()` flips `current` to
    /// `requestResult` to model the system dialog's outcome.
    final class AuthStubLibrary: PhotoLibrary, @unchecked Sendable {
        var current: PHAuthorizationStatus
        var requestResult: PHAuthorizationStatus

        init(current: PHAuthorizationStatus, requestResult: PHAuthorizationStatus) {
            self.current = current
            self.requestResult = requestResult
        }

        var currentAuthorizationStatus: PHAuthorizationStatus { current }
        func authorizationStatus() async -> PHAuthorizationStatus { current }
        func requestAuthorization() async -> PHAuthorizationStatus {
            current = requestResult
            return requestResult
        }
        func fetchAllPhotoAssets() async -> [PhotoAssetDescriptor] { [] }
        func thumbnailCGImage(localIdentifier: String, pixelSize: Int) async -> CGImage? { nil }
        func thumbnailStream(localIdentifier: String, pixelSize: Int) -> AsyncStream<CGImage> {
            AsyncStream { $0.finish() }
        }
        func deleteAssets(localIdentifiers: [String]) async throws {}
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([ScannedAsset.self, DuplicateGroupRecord.self, ScanSession.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test
    func photoAccessReflectsRealStatusAtInit() throws {
        let container = try makeContainer()
        let library = AuthStubLibrary(current: .denied, requestResult: .denied)
        let store = ScanStore(modelContext: container.mainContext, library: library)
        #expect(store.photoAccess == .denied)
    }

    @Test
    func requestAccessUpdatesPhotoAccess() async throws {
        let container = try makeContainer()
        let library = AuthStubLibrary(current: .notDetermined, requestResult: .authorized)
        let store = ScanStore(modelContext: container.mainContext, library: library)
        #expect(store.photoAccess == .needsPriming)

        await store.requestAccess()
        #expect(store.photoAccess == .granted)
    }

    @Test
    func refreshPullsLatestStatusFromLibrary() throws {
        let container = try makeContainer()
        let library = AuthStubLibrary(current: .denied, requestResult: .denied)
        let store = ScanStore(modelContext: container.mainContext, library: library)
        #expect(store.photoAccess == .denied)

        // User granted access in Settings; app foregrounds and refreshes.
        library.current = .authorized
        store.refreshAuthorizationStatus()
        #expect(store.photoAccess == .granted)
    }

    @Test
    func runScanBailsWhenAccessIsLimited() async throws {
        let container = try makeContainer()
        let library = AuthStubLibrary(current: .limited, requestResult: .limited)
        let store = ScanStore(modelContext: container.mainContext, library: library)

        await store.runScan(forceRescan: false)

        #expect(store.isScanning == false)
        #expect(store.lastError == "Photo library access denied.")
        #expect(store.latestSession == nil)
    }

    @Test
    func runScanBailsWhenAccessIsDenied() async throws {
        let container = try makeContainer()
        let library = AuthStubLibrary(current: .denied, requestResult: .denied)
        let store = ScanStore(modelContext: container.mainContext, library: library)

        await store.runScan(forceRescan: false)

        #expect(store.isScanning == false)
        #expect(store.lastError == "Photo library access denied.")
        #expect(store.latestSession == nil)
    }
}
