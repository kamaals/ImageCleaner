import Testing
@testable import ImageCleaner

/// Tests for `ScanViewModel.cancelMockScan()` and the race-safety of
/// repeated `startMockScan()` calls.
@MainActor
struct ScanViewModelCancellationTests {
    @Test func cancelMockScanStopsScanningFlag() {
        let vm = ScanViewModel()
        vm.startMockScan()
        #expect(vm.isScanning == true)

        vm.cancelMockScan()
        #expect(vm.isScanning == false)
    }

    @Test func cancelMockScanIsNoOpWhenNotScanning() {
        let vm = ScanViewModel()
        vm.cancelMockScan() // must not crash or mutate unrelated state
        #expect(vm.isScanning == false)
        #expect(vm.scannedCount == 0)
    }

    @Test func startMockScanReplacesPreviousTask() async {
        let vm = ScanViewModel()
        vm.startMockScan()
        // Let the first scan tick a bit
        try? await Task.sleep(for: .milliseconds(100))
        let firstScannedCount = vm.scannedCount
        #expect(firstScannedCount > 0)

        // Re-start — the previous task should be cancelled and count reset to 0.
        vm.startMockScan()
        #expect(vm.scannedCount == 0)
        #expect(vm.isScanning == true)
    }

    @Test func startMockScanAfterCancelResumesNormally() async {
        let vm = ScanViewModel()
        vm.startMockScan()
        vm.cancelMockScan()
        #expect(vm.isScanning == false)

        // Restart should work as expected
        vm.startMockScan()
        #expect(vm.isScanning == true)
        try? await Task.sleep(for: .milliseconds(100))
        #expect(vm.scannedCount > 0)
    }
}
