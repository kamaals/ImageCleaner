import Foundation
import SwiftUI

/// A standalone photo that doesn't belong to a duplicate group. Used by the
/// Blank Photos and Screenshots screens where each cell is exactly one image.
struct SinglePhoto: Identifiable, Equatable {
    let id: UUID
    let shade: Double
    let displayHeight: CGFloat
    let fileSize: Int64
    let createdAt: Date
    var isSelected: Bool

    init(
        id: UUID = UUID(),
        shade: Double,
        displayHeight: CGFloat,
        fileSize: Int64,
        createdAt: Date = .now,
        isSelected: Bool = false
    ) {
        self.id = id
        self.shade = shade
        self.displayHeight = displayHeight
        self.fileSize = fileSize
        self.createdAt = createdAt
        self.isSelected = isSelected
    }

    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: createdAt)
    }
}

// MARK: - Mock Data

extension SinglePhoto {
    /// Mock dataset for the Blank Photos screen. Shades skew high (near-white)
    /// so the waterfall renders in a way that reads as "blank-ish".
    static let blankMockData: [SinglePhoto] = [
        SinglePhoto(shade: 0.92, displayHeight: 180, fileSize: 320_000, createdAt: Date.now.addingTimeInterval(-86400)),
        SinglePhoto(shade: 0.95, displayHeight: 140, fileSize: 280_000, createdAt: Date.now.addingTimeInterval(-172800)),
        SinglePhoto(shade: 0.88, displayHeight: 220, fileSize: 410_000, createdAt: Date.now.addingTimeInterval(-259200)),
        SinglePhoto(shade: 0.96, displayHeight: 120, fileSize: 180_000, createdAt: Date.now.addingTimeInterval(-345600)),
        SinglePhoto(shade: 0.90, displayHeight: 160, fileSize: 350_000, createdAt: Date.now.addingTimeInterval(-432000)),
        SinglePhoto(shade: 0.93, displayHeight: 190, fileSize: 440_000, createdAt: Date.now.addingTimeInterval(-518400)),
        SinglePhoto(shade: 0.89, displayHeight: 130, fileSize: 250_000, createdAt: Date.now.addingTimeInterval(-604800)),
    ]

    /// Mock dataset for the Screenshots screen. Shades vary more (capture UI
    /// with darker regions) and sizes run a bit larger on average.
    static let screenshotMockData: [SinglePhoto] = [
        SinglePhoto(shade: 0.35, displayHeight: 240, fileSize: 2_400_000, createdAt: Date.now.addingTimeInterval(-86400)),
        SinglePhoto(shade: 0.55, displayHeight: 180, fileSize: 1_900_000, createdAt: Date.now.addingTimeInterval(-172800)),
        SinglePhoto(shade: 0.40, displayHeight: 200, fileSize: 2_100_000, createdAt: Date.now.addingTimeInterval(-259200)),
        SinglePhoto(shade: 0.70, displayHeight: 150, fileSize: 1_500_000, createdAt: Date.now.addingTimeInterval(-345600)),
        SinglePhoto(shade: 0.45, displayHeight: 220, fileSize: 2_800_000, createdAt: Date.now.addingTimeInterval(-432000)),
        SinglePhoto(shade: 0.60, displayHeight: 170, fileSize: 1_700_000, createdAt: Date.now.addingTimeInterval(-518400)),
        SinglePhoto(shade: 0.50, displayHeight: 190, fileSize: 2_200_000, createdAt: Date.now.addingTimeInterval(-604800)),
        SinglePhoto(shade: 0.30, displayHeight: 250, fileSize: 3_100_000, createdAt: Date.now.addingTimeInterval(-691200)),
        SinglePhoto(shade: 0.65, displayHeight: 160, fileSize: 1_800_000, createdAt: Date.now.addingTimeInterval(-777600)),
    ]
}
