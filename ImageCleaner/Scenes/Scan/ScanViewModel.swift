import SwiftUI

/// Presentation model for the scanning state shown in `ScanTransitionView`
/// and `ScanView`. Thin wrapper that mirrors live `ScanStore` progress into
/// the counter properties the view already binds to, so the home/scan UI
/// doesn't need to know about PhotoKit.
@Observable @MainActor
final class ScanViewModel {
    var totalPhotos = 0
    var scannedCount = 0
    var duplicatesFound = 0
    var screenshotsFound = 0
    var blankPhotosFound = 0
    var isScanning = false
    var scanCompleted = false

    private var scanGeneration = 0

    var progress: Double {
        guard totalPhotos > 0 else { return 0 }
        return min(Double(scannedCount) / Double(totalPhotos), 1.0)
    }

    var duplicatesText: String {
        duplicatesFound > 0 ? "\(duplicatesFound) Duplicates found...." : "No Duplicates Yet"
    }

    var screenshotsText: String {
        screenshotsFound > 0 ? "\(screenshotsFound) Screenshots found...." : "No Screenshots Yet"
    }

    var blankPhotosText: String {
        blankPhotosFound > 0 ? "\(blankPhotosFound) Blank Photos found...." : "No Blank Photos Yet"
    }

    /// Kicks off a real scan. The store is driven async; progress snapshots
    /// should be forwarded into `syncFromProgress(_:)` by the view.
    func startScan(store: ScanStore, forceRescan: Bool) {
        scanGeneration += 1
        let thisGeneration = scanGeneration

        isScanning = true
        scanCompleted = false
        totalPhotos = 0
        scannedCount = 0
        duplicatesFound = 0
        screenshotsFound = 0
        blankPhotosFound = 0

        Task { [weak self, weak store] in
            guard let store else { return }
            await store.runScan(forceRescan: forceRescan)
            guard let self, self.scanGeneration == thisGeneration else { return }
            // Sync final state from the persisted session so the scan-end
            // counters reflect what actually landed in the store.
            if let session = store.latestSession {
                self.totalPhotos = session.totalScanned
                self.scannedCount = session.totalScanned
                self.duplicatesFound = session.duplicateGroupCount
                self.screenshotsFound = session.screenshotCount
                self.blankPhotosFound = session.blankCount
            }
            self.isScanning = false
            self.scanCompleted = true
        }
    }

    /// Mirror a live `ScanProgress` snapshot into the observable counters.
    /// Called from the view via `.onChange(of: store.scanProgress)`.
    func syncFromProgress(_ progress: ScanProgress) {
        totalPhotos = progress.total
        scannedCount = progress.processed
        screenshotsFound = progress.screenshotsFound
        blankPhotosFound = progress.blanksFound
        duplicateGroupsFound(progress.duplicateGroupsFound)
    }

    private func duplicateGroupsFound(_ count: Int) {
        duplicatesFound = count
    }

    func cancelScan() {
        scanGeneration += 1
        isScanning = false
    }

    // Legacy mock-scan entry for previews / tests.
    func startMockScan() {
        scanGeneration += 1
        let thisGeneration = scanGeneration

        isScanning = true
        scanCompleted = false
        totalPhotos = 23_567
        scannedCount = 0
        duplicatesFound = 0
        screenshotsFound = 0
        blankPhotosFound = 0

        Task {
            while scannedCount < totalPhotos {
                try? await Task.sleep(for: .milliseconds(10))
                guard scanGeneration == thisGeneration else { return }
                scannedCount = min(scannedCount + Int.random(in: 40...80), totalPhotos)

                if scannedCount > 2_000 && duplicatesFound == 0 { duplicatesFound = 12 }
                if duplicatesFound > 0 && duplicatesFound < 145 {
                    duplicatesFound = min(duplicatesFound + Int.random(in: 1...5), 145)
                }
                if scannedCount > 5_000 && screenshotsFound == 0 { screenshotsFound = 30 }
                if screenshotsFound > 0 && screenshotsFound < 214 {
                    screenshotsFound = min(screenshotsFound + Int.random(in: 2...8), 214)
                }
            }
            guard scanGeneration == thisGeneration else { return }
            isScanning = false
            scanCompleted = true
        }
    }

    func cancelMockScan() { cancelScan() }
}
