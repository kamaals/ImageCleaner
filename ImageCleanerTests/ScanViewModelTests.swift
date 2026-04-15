import Testing
@testable import ImageCleaner

struct ScanViewModelTests {
    @Test @MainActor func initialState() {
        let vm = ScanViewModel()
        #expect(vm.totalPhotos == 0)
        #expect(vm.scannedCount == 0)
        #expect(vm.duplicatesFound == 0)
        #expect(vm.screenshotsFound == 0)
        #expect(vm.blankPhotosFound == 0)
        #expect(vm.isScanning == false)
    }

    @Test @MainActor func progressIsZeroWhenNoPhotos() {
        let vm = ScanViewModel()
        #expect(vm.progress == 0)
    }

    @Test @MainActor func progressCalculation() {
        let vm = ScanViewModel()
        vm.totalPhotos = 100
        vm.scannedCount = 75
        #expect(vm.progress == 0.75)
    }

    @Test @MainActor func progressCapsAtOne() {
        let vm = ScanViewModel()
        vm.totalPhotos = 100
        vm.scannedCount = 150
        #expect(vm.progress == 1.0)
    }

    @Test @MainActor func duplicatesLabel() {
        let vm = ScanViewModel()
        vm.duplicatesFound = 0
        #expect(vm.duplicatesText == "No Duplicates Yet")
        vm.duplicatesFound = 145
        #expect(vm.duplicatesText == "145 Duplicates found....")
    }

    @Test @MainActor func screenshotsLabel() {
        let vm = ScanViewModel()
        vm.screenshotsFound = 0
        #expect(vm.screenshotsText == "No Screenshots Yet")
        vm.screenshotsFound = 214
        #expect(vm.screenshotsText == "214 Screenshots found....")
    }

    @Test @MainActor func blankPhotosLabel() {
        let vm = ScanViewModel()
        vm.blankPhotosFound = 0
        #expect(vm.blankPhotosText == "No Blank Photos Yet")
        vm.blankPhotosFound = 3
        #expect(vm.blankPhotosText == "3 Blank Photos found....")
    }
}
