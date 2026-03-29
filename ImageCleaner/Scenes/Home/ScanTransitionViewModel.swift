import SwiftUI

@Observable
final class ScanTransitionViewModel {
    var isScanning = false

    var textRevealProgress: Double = 0
    var textScale: Double = 1.0

    var homeContentOpacity: Double = 1.0
    var scanContentOpacity: Double = 0

    static let targetScale = 40.0 / 120.0

    func jumpToScanState() {
        isScanning = true
        textRevealProgress = 1.0
        textScale = Self.targetScale
        homeContentOpacity = 0
        scanContentOpacity = 1.0
    }

    func jumpToHomeState() {
        isScanning = false
        textRevealProgress = 0
        textScale = 1.0
        homeContentOpacity = 1.0
        scanContentOpacity = 0
    }

    func animateToScan() {
        withAnimation(.easeInOut(duration: 0.35)) {
            textRevealProgress = 1.0
            homeContentOpacity = 0
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.85).delay(0.2)) {
            textScale = Self.targetScale
            isScanning = true
        }

        withAnimation(.easeIn(duration: 0.3).delay(0.5)) {
            scanContentOpacity = 1.0
        }
    }

    func animateToHome() {
        // Same structure as animateToScan, reversed values

        withAnimation(.easeInOut(duration: 0.35)) {
            textRevealProgress = 0
            homeContentOpacity = 1.0
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.85).delay(0.2)) {
            textScale = 1.0
            isScanning = false
        }

        withAnimation(.easeIn(duration: 0.3).delay(0.5)) {
            scanContentOpacity = 0
        }
    }
}
