import SwiftUI

@Observable @MainActor
final class ScanTransitionViewModel {
    var isScanning = false
    var contentEntered = false

    var textRevealProgress: Double = 0
    var textScale: Double = 1.0

    var scanContentOpacity: Double = 0
    var viewResultsVisible = false
    var forceRescanVisible = false

    static let targetScale = 40.0 / 120.0

    // MARK: - Reduce Motion (instant jumps)

    func jumpToScanState() {
        isScanning = true
        contentEntered = true
        textRevealProgress = 1.0
        textScale = Self.targetScale
        scanContentOpacity = 1.0
        viewResultsVisible = false
        forceRescanVisible = false
    }

    func jumpToHomeState() {
        isScanning = false
        contentEntered = true
        textRevealProgress = 0
        textScale = 1.0
        scanContentOpacity = 0
        viewResultsVisible = true
        forceRescanVisible = true
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
        // Stagger buttons in after text starts entering
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.1)) {
            viewResultsVisible = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.2)) {
            forceRescanVisible = true
        }
    }

    /// Forward: buttons exit (reverse stagger) → text morphs → scan content appears
    func animateToScan() {
        // Step 1: Exit buttons in reverse stagger (last in → first out)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
            forceRescanVisible = false
        }
        // View Last Results exits second; its completion fires after both are gone
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.2)) {
            viewResultsVisible = false
        } completion: {
            // Step 2: Buttons gone → morph SCAN → SCANNING + transition layout
            withAnimation(.easeInOut(duration: 0.35)) {
                self.textRevealProgress = 1.0
                self.textScale = Self.targetScale
                self.isScanning = true
            } completion: {
                // Step 3: Show scan content
                withAnimation(.easeIn(duration: 0.3)) {
                    self.scanContentOpacity = 1.0
                }
            }
        }
    }

    /// Reverse: scan content + text morph back → buttons re-enter (stagger)
    func animateToHome() {
        // Step 1: Fade scan content + morph SCANNING → SCAN
        withAnimation(.easeInOut(duration: 0.3)) {
            scanContentOpacity = 0
        }
        withAnimation(.easeInOut(duration: 0.35)) {
            textRevealProgress = 0
            textScale = 1.0
            isScanning = false
        } completion: {
            // Step 2: Buttons slide back in (stagger)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                self.viewResultsVisible = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.1)) {
                self.forceRescanVisible = true
            }
        }
    }
}
