import Testing
@testable import ImageCleaner

struct ScanTransitionViewModelTests {
    @Test @MainActor func initialStateIsHome() {
        let vm = ScanTransitionViewModel()
        #expect(vm.isScanning == false)
        #expect(vm.contentEntered == false)
        #expect(vm.textRevealProgress == 0)
        #expect(vm.textScale == 1.0)
    }

    @Test @MainActor func scanningEndState() {
        let vm = ScanTransitionViewModel()
        vm.jumpToScanState()
        #expect(vm.isScanning == true)
        #expect(vm.contentEntered == true)
        #expect(vm.textRevealProgress == 1.0)
        #expect(vm.textScale == ScanTransitionViewModel.targetScale)
    }

    @Test @MainActor func homeEndState() {
        let vm = ScanTransitionViewModel()
        vm.jumpToScanState()
        vm.jumpToHomeState()
        #expect(vm.isScanning == false)
        #expect(vm.contentEntered == true)
        #expect(vm.textRevealProgress == 0)
        #expect(vm.textScale == 1.0)
    }

    @Test @MainActor func targetScaleIs40Over120() {
        #expect(ScanTransitionViewModel.targetScale == 40.0 / 120.0)
    }

    @Test @MainActor func entranceState() {
        let vm = ScanTransitionViewModel()
        #expect(vm.contentEntered == false)
        vm.animateEntrance()
        #expect(vm.contentEntered == true)
    }

    @Test @MainActor func jumpToEnteredState() {
        let vm = ScanTransitionViewModel()
        vm.jumpToEnteredState()
        #expect(vm.contentEntered == true)
    }
}
