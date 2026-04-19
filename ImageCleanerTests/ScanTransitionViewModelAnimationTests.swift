import Testing
@testable import ImageCleaner

/// Tests for animation methods on `ScanTransitionViewModel`.
///
/// SwiftUI's `withAnimation { ... }` runs its closure SYNCHRONOUSLY — only the
/// visual interpolation is deferred. So we can verify immediate state mutations
/// without waiting. Completion callbacks (passed via `withAnimation { ... } completion:`)
/// fire AFTER the animation duration; for those we await a generous timeout.
@MainActor
struct ScanTransitionViewModelAnimationTests {

    // MARK: - jump helpers (state machine endpoints)

    @Test func jumpToScanStateRevealsAllScanElements() {
        let vm = ScanTransitionViewModel()
        vm.jumpToScanState()
        #expect(vm.photosTextVisible == true)
        #expect(vm.progressBarVisible == true)
        #expect(vm.scannedTextVisible == true)
        #expect(vm.duplicatesRowVisible == true)
        #expect(vm.screenshotsRowVisible == true)
        #expect(vm.blankPhotosRowVisible == true)
    }

    @Test func jumpToScanStateHidesHomeButtons() {
        let vm = ScanTransitionViewModel()
        vm.viewResultsVisible = true
        vm.forceRescanVisible = true
        vm.jumpToScanState()
        #expect(vm.viewResultsVisible == false)
        #expect(vm.forceRescanVisible == false)
    }

    @Test func jumpToHomeStateHidesAllScanElementsAndShowsButtons() {
        let vm = ScanTransitionViewModel()
        vm.jumpToScanState() // start fully in scan
        vm.jumpToHomeState()
        #expect(vm.photosTextVisible == false)
        #expect(vm.progressBarVisible == false)
        #expect(vm.scannedTextVisible == false)
        #expect(vm.duplicatesRowVisible == false)
        #expect(vm.screenshotsRowVisible == false)
        #expect(vm.blankPhotosRowVisible == false)
        #expect(vm.viewResultsVisible == true)
        #expect(vm.forceRescanVisible == true)
        #expect(vm.appIconVisible == true)
        #expect(vm.scanningTextVisible == true)
    }

    @Test func jumpToEnteredStateRevealsHomeButtonsOnly() {
        let vm = ScanTransitionViewModel()
        vm.jumpToEnteredState()
        #expect(vm.contentEntered == true)
        #expect(vm.viewResultsVisible == true)
        #expect(vm.forceRescanVisible == true)
        // scan-side state should not flip
        #expect(vm.isScanning == false)
        #expect(vm.photosTextVisible == false)
    }

    // MARK: - animateEntrance

    @Test func animateEntranceImmediatelyMarksContentEntered() {
        let vm = ScanTransitionViewModel()
        vm.animateEntrance()
        #expect(vm.contentEntered == true)
        // Buttons fade in via withAnimation .delay() — closure body still runs synchronously
        #expect(vm.viewResultsVisible == true)
        #expect(vm.forceRescanVisible == true)
    }

    // MARK: - animateToScan

    @Test func animateToScanImmediatelyHidesHomeButtons() {
        let vm = ScanTransitionViewModel()
        vm.viewResultsVisible = true
        vm.forceRescanVisible = true
        vm.animateToScan()
        // First withAnimation closure runs synchronously
        #expect(vm.forceRescanVisible == false)
        // Second withAnimation has a delay but the state mutation still executes immediately
        #expect(vm.viewResultsVisible == false)
    }

    @Test func animateToScanCompletionFlipsToScanning() async {
        let vm = ScanTransitionViewModel()
        vm.animateToScan()
        // Wait beyond the chained 0.6s spring + 0.2s delay + 0.35s ease + stagger
        try? await Task.sleep(for: .seconds(2))
        #expect(vm.isScanning == true)
        #expect(vm.textRevealProgress == 1.0)
        #expect(vm.textScale == ScanTransitionViewModel.targetScale)
    }

    // MARK: - animateToHome

    @Test func animateToHomeBeginsStaggerOutOfScanElements() {
        let vm = ScanTransitionViewModel()
        vm.jumpToScanState() // fully in scan, all elements visible
        vm.animateToHome()
        // First scan-element to fade is the bottom row (blankPhotos)
        #expect(vm.blankPhotosRowVisible == false)
    }

    @Test func animateToHomeCompletionRestoresHomeState() async {
        let vm = ScanTransitionViewModel()
        vm.jumpToScanState()
        vm.animateToHome()
        try? await Task.sleep(for: .seconds(2))
        #expect(vm.isScanning == false)
        #expect(vm.textRevealProgress == 0)
        #expect(vm.textScale == 1.0)
        #expect(vm.viewResultsVisible == true)
        #expect(vm.forceRescanVisible == true)
    }

    // MARK: - animateToResults

    @Test func animateToResultsInvokesCompletionAndResetsToHome() async {
        let vm = ScanTransitionViewModel()
        vm.jumpToScanState()

        let didNavigate = NavigationFlag()
        vm.animateToResults { didNavigate.value = true }

        try? await Task.sleep(for: .seconds(2))
        #expect(didNavigate.value == true)
        // jumpToHomeState is invoked at the end so we should be back at the home endpoint
        #expect(vm.isScanning == false)
    }
}

@MainActor
private final class NavigationFlag {
    var value: Bool = false
}
