import Testing
import SwiftUI
@testable import ImageCleaner

struct HomeViewModelTests {
    @Test func forceRescanDefaultsToFalse() {
        let vm = HomeViewModel()
        #expect(vm.forceRescan == false)
    }

    @Test func forceRescanCanBeToggled() {
        let vm = HomeViewModel()
        vm.forceRescan = true
        #expect(vm.forceRescan == true)
    }

    @Test func navigationPathStartsEmpty() {
        let vm = HomeViewModel()
        #expect(vm.navigationPath.isEmpty)
    }

    @Test func navigateToScanAddsToPath() {
        let vm = HomeViewModel()
        vm.navigateToScan()
        #expect(vm.navigationPath.count == 1)
    }

    @Test func navigateToResultsAddsToPath() {
        let vm = HomeViewModel()
        vm.navigateToResults()
        #expect(vm.navigationPath.count == 1)
    }
}
