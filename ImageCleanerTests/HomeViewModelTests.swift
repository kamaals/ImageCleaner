import Testing
import SwiftUI
@testable import ImageCleaner

struct HomeViewModelTests {
    @Test @MainActor func forceRescanDefaultsToFalse() {
        let vm = HomeViewModel()
        #expect(vm.forceRescan == false)
    }

    @Test @MainActor func forceRescanCanBeToggled() {
        let vm = HomeViewModel()
        vm.forceRescan = true
        #expect(vm.forceRescan == true)
    }

    @Test @MainActor func navigationPathStartsEmpty() {
        let vm = HomeViewModel()
        #expect(vm.navigationPath.isEmpty)
    }

    @Test @MainActor func navigateToScanAddsToPath() {
        let vm = HomeViewModel()
        vm.navigateToScan()
        #expect(vm.navigationPath.count == 1)
    }

    @Test @MainActor func navigateToResultsAddsToPath() {
        let vm = HomeViewModel()
        vm.navigateToResults()
        #expect(vm.navigationPath.count == 1)
    }
}
