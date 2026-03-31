import SwiftUI

@Observable @MainActor
final class ScanTransitionViewModel {
    var isScanning = false
    var contentEntered = false

    var textRevealProgress: Double = 0
    var textScale: Double = 1.0

    // Home button visibility (per-button stagger)
    var viewResultsVisible = false
    var forceRescanVisible = false

    // Scan content element visibility (per-element stagger)
    var photosTextVisible = false
    var progressBarVisible = false
    var scannedTextVisible = false
    var duplicatesRowVisible = false
    var screenshotsRowVisible = false
    var blankPhotosRowVisible = false

    static let targetScale = 40.0 / 120.0

    // MARK: - Reduce Motion (instant jumps)

    func jumpToScanState() {
        isScanning = true
        contentEntered = true
        textRevealProgress = 1.0
        textScale = Self.targetScale
        viewResultsVisible = false
        forceRescanVisible = false
        showAllScanElements()
    }

    func jumpToHomeState() {
        isScanning = false
        contentEntered = true
        textRevealProgress = 0
        textScale = 1.0
        viewResultsVisible = true
        forceRescanVisible = true
        hideAllScanElements()
    }

    func jumpToEnteredState() {
        contentEntered = true
        viewResultsVisible = true
        forceRescanVisible = true
    }

    // MARK: - Animated Transitions

    /// Entrance: SCAN text slides in, then buttons stagger in
    func animateEntrance() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            contentEntered = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.1)) {
            viewResultsVisible = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.2)) {
            forceRescanVisible = true
        }
    }

    /// Forward: buttons exit → text morphs → scan elements stagger in
    func animateToScan() {
        // Step 1: Exit buttons in reverse stagger (last in → first out)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
            forceRescanVisible = false
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.2)) {
            viewResultsVisible = false
        } completion: {
            // Step 2: Buttons gone → morph SCAN → SCANNING + transition layout
            withAnimation(.easeInOut(duration: 0.35)) {
                self.textRevealProgress = 1.0
                self.textScale = Self.targetScale
                self.isScanning = true
            } completion: {
                // Step 3: Stagger scan content elements in
                self.staggerScanElementsIn()
            }
        }
    }

    /// Reverse: scan elements exit → text morph back → buttons re-enter
    func animateToHome() {
        // Step 1: Exit scan elements in reverse stagger (last in → first out)
        staggerScanElementsOut {
            // Step 2: All scan elements gone → morph text back
            withAnimation(.easeInOut(duration: 0.35)) {
                self.textRevealProgress = 0
                self.textScale = 1.0
                self.isScanning = false
            } completion: {
                // Step 3: Buttons slide back in (stagger)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    self.viewResultsVisible = true
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.1)) {
                    self.forceRescanVisible = true
                }
            }
        }
    }

    // MARK: - Scan Element Stagger Helpers

    private func staggerScanElementsIn() {
        let spring = Animation.easeOut(duration: 0.3)
        let interval = 0.08

        withAnimation(spring) {
            photosTextVisible = true
        }
        withAnimation(spring.delay(interval)) {
            progressBarVisible = true
        }
        withAnimation(spring.delay(interval * 2)) {
            scannedTextVisible = true
        }
        withAnimation(spring.delay(interval * 3)) {
            duplicatesRowVisible = true
        }
        withAnimation(spring.delay(interval * 4)) {
            screenshotsRowVisible = true
        }
        withAnimation(spring.delay(interval * 5)) {
            blankPhotosRowVisible = true
        }
    }

    private func staggerScanElementsOut(completion done: @MainActor @escaping @Sendable () -> Void) {
        let anim = Animation.easeIn(duration: 0.2)
        let interval = 0.06

        // Reverse order: last entered exits first
        withAnimation(anim) {
            blankPhotosRowVisible = false
        }
        withAnimation(anim.delay(interval)) {
            screenshotsRowVisible = false
        }
        withAnimation(anim.delay(interval * 2)) {
            duplicatesRowVisible = false
        }
        withAnimation(anim.delay(interval * 3)) {
            scannedTextVisible = false
        }
        withAnimation(anim.delay(interval * 4)) {
            progressBarVisible = false
        }
        // Completion on last element to exit — chains into next step
        withAnimation(anim.delay(interval * 5)) {
            photosTextVisible = false
        } completion: {
            done()
        }
    }

    private func showAllScanElements() {
        photosTextVisible = true
        progressBarVisible = true
        scannedTextVisible = true
        duplicatesRowVisible = true
        screenshotsRowVisible = true
        blankPhotosRowVisible = true
    }

    private func hideAllScanElements() {
        photosTextVisible = false
        progressBarVisible = false
        scannedTextVisible = false
        duplicatesRowVisible = false
        screenshotsRowVisible = false
        blankPhotosRowVisible = false
    }
}
