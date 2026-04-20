import Testing
import Foundation
@testable import ImageCleaner

/// Tests for the async mock-scan flow on `ScanViewModel`.
@MainActor
struct ScanViewModelMockScanTests {

    @Test func startMockScanInitializesStateSynchronously() {
        let vm = ScanViewModel()
        vm.startMockScan()
        #expect(vm.isScanning == true)
        #expect(vm.scanCompleted == false)
        #expect(vm.totalPhotos == 23_567)
        #expect(vm.scannedCount == 0)
        #expect(vm.duplicatesFound == 0)
        #expect(vm.screenshotsFound == 0)
        #expect(vm.blankPhotosFound == 0)
    }

    @Test func startMockScanResetsFromPreviousResults() {
        let vm = ScanViewModel()
        // pretend an earlier scan left state behind
        vm.totalPhotos = 100
        vm.scannedCount = 50
        vm.duplicatesFound = 10
        vm.screenshotsFound = 8
        vm.blankPhotosFound = 3
        vm.scanCompleted = true

        vm.startMockScan()

        #expect(vm.scanCompleted == false)
        #expect(vm.scannedCount == 0)
        #expect(vm.duplicatesFound == 0)
        #expect(vm.screenshotsFound == 0)
        #expect(vm.blankPhotosFound == 0)
    }

    @Test func startMockScanProgressesScannedCount() async {
        let vm = ScanViewModel()
        vm.startMockScan()
        // After ~200ms we should have ticked at least a few iterations
        try? await Task.sleep(for: .milliseconds(200))
        #expect(vm.scannedCount > 0)
    }

    @Test func startMockScanEventuallyDiscoversDuplicates() async {
        let vm = ScanViewModel()
        vm.startMockScan()
        // Duplicates start when scannedCount > 2_000; at 60 avg/10ms that's
        // ~333ms, but with parallel Swift Testing jobs the MainActor can be
        // contended, so allow a generous upper bound and poll rather than
        // racing a fixed sleep.
        let deadline = Date().addingTimeInterval(5)
        while vm.duplicatesFound == 0 && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(50))
        }
        #expect(vm.duplicatesFound > 0)
    }
}
