import SwiftUI

@Observable @MainActor
final class ScanViewModel {
    var totalPhotos = 0
    var scannedCount = 0
    var duplicatesFound = 0
    var screenshotsFound = 0
    var blankPhotosFound = 0
    var isScanning = false
    var scanCompleted = false

    private var scanGeneration = 0

    var progress: Double {
        guard totalPhotos > 0 else { return 0 }
        return min(Double(scannedCount) / Double(totalPhotos), 1.0)
    }

    var duplicatesText: String {
        duplicatesFound > 0 ? "\(duplicatesFound) Duplicates found...." : "No Duplicates Yet"
    }

    var screenshotsText: String {
        screenshotsFound > 0 ? "\(screenshotsFound) Screenshots found...." : "No Screenshots Yet"
    }

    var blankPhotosText: String {
        blankPhotosFound > 0 ? "\(blankPhotosFound) Blank Photos found...." : "No Blank Photos Yet"
    }

    func startMockScan() {
        scanGeneration += 1
        let thisGeneration = scanGeneration

        isScanning = true
        scanCompleted = false
        totalPhotos = 23_567
        scannedCount = 0
        duplicatesFound = 0
        screenshotsFound = 0
        blankPhotosFound = 0

        Task {
            while scannedCount < totalPhotos {
                try? await Task.sleep(for: .milliseconds(10))
                guard scanGeneration == thisGeneration else { return }
                scannedCount = min(scannedCount + Int.random(in: 40...80), totalPhotos)

                if scannedCount > 2_000 && duplicatesFound == 0 {
                    duplicatesFound = 12
                }
                if duplicatesFound > 0 && duplicatesFound < 145 {
                    duplicatesFound = min(duplicatesFound + Int.random(in: 1...5), 145)
                }

                if scannedCount > 5_000 && screenshotsFound == 0 {
                    screenshotsFound = 30
                }
                if screenshotsFound > 0 && screenshotsFound < 214 {
                    screenshotsFound = min(screenshotsFound + Int.random(in: 2...8), 214)
                }
            }
            guard scanGeneration == thisGeneration else { return }
            isScanning = false
            scanCompleted = true
        }
    }

    func cancelMockScan() {
        scanGeneration += 1
        isScanning = false
    }
}
