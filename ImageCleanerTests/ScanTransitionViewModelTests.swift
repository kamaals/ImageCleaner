import Testing
@testable import ImageCleaner

struct ScanTransitionViewModelTests {
    @Test func initialStateIsHome() {
        let vm = ScanTransitionViewModel()
        #expect(vm.isScanning == false)
        #expect(vm.textRevealProgress == 0)
        #expect(vm.textScale == 1.0)
        #expect(vm.homeContentOpacity == 1.0)
        #expect(vm.scanContentOpacity == 0)
    }

    @Test func scanningEndState() {
        let vm = ScanTransitionViewModel()
        vm.jumpToScanState()
        #expect(vm.isScanning == true)
        #expect(vm.textRevealProgress == 1.0)
        #expect(vm.textScale == ScanTransitionViewModel.targetScale)
        #expect(vm.homeContentOpacity == 0)
        #expect(vm.scanContentOpacity == 1.0)
    }

    @Test func homeEndState() {
        let vm = ScanTransitionViewModel()
        vm.jumpToScanState()
        vm.jumpToHomeState()
        #expect(vm.isScanning == false)
        #expect(vm.textRevealProgress == 0)
        #expect(vm.textScale == 1.0)
        #expect(vm.homeContentOpacity == 1.0)
        #expect(vm.scanContentOpacity == 0)
    }

    @Test func targetScaleIs40Over120() {
        #expect(ScanTransitionViewModel.targetScale == 40.0 / 120.0)
    }
}
