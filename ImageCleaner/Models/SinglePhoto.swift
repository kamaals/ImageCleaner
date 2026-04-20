import Foundation
import SwiftUI

/// A standalone photo that doesn't belong to a duplicate group. Used by the
/// Blank Photos and Screenshots screens where each cell is exactly one image.
struct SinglePhoto: Identifiable, Equatable {
    let id: UUID
    /// PhotoKit asset identifier when backed by a real photo; `nil` for mocks.
    let localIdentifier: String?
    let shade: Double
    /// Image aspect ratio (width / height). Drives the Pinterest grid's
    /// per-cell height: `cellHeight = columnWidth / aspectRatio`.
    let aspectRatio: Double
    let fileSize: Int64
    let createdAt: Date
    var isSelected: Bool

    init(
        id: UUID = UUID(),
        localIdentifier: String? = nil,
        shade: Double,
        aspectRatio: Double = 1.0,
        fileSize: Int64,
        createdAt: Date = .now,
        isSelected: Bool = false
    ) {
        self.id = id
        self.localIdentifier = localIdentifier
        self.shade = shade
        self.aspectRatio = aspectRatio
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
        SinglePhoto(shade: 0.92, aspectRatio: 0.75, fileSize: 320_000, createdAt: Date.now.addingTimeInterval(-86400)),
        SinglePhoto(shade: 0.95, aspectRatio: 1.33, fileSize: 280_000, createdAt: Date.now.addingTimeInterval(-172800)),
        SinglePhoto(shade: 0.88, aspectRatio: 0.67, fileSize: 410_000, createdAt: Date.now.addingTimeInterval(-259200)),
        SinglePhoto(shade: 0.96, aspectRatio: 1.0, fileSize: 180_000, createdAt: Date.now.addingTimeInterval(-345600)),
        SinglePhoto(shade: 0.90, aspectRatio: 0.8, fileSize: 350_000, createdAt: Date.now.addingTimeInterval(-432000)),
        SinglePhoto(shade: 0.93, aspectRatio: 0.7, fileSize: 440_000, createdAt: Date.now.addingTimeInterval(-518400)),
        SinglePhoto(shade: 0.89, aspectRatio: 1.5, fileSize: 250_000, createdAt: Date.now.addingTimeInterval(-604800)),
    ]

    /// Mock dataset for the Screenshots screen. Aspect ratios skew portrait
    /// (phone-shaped) so the waterfall reads as a screenshot gallery.
    static let screenshotMockData: [SinglePhoto] = [
        SinglePhoto(shade: 0.35, aspectRatio: 0.46, fileSize: 2_400_000, createdAt: Date.now.addingTimeInterval(-86400)),
        SinglePhoto(shade: 0.55, aspectRatio: 0.46, fileSize: 1_900_000, createdAt: Date.now.addingTimeInterval(-172800)),
        SinglePhoto(shade: 0.40, aspectRatio: 0.46, fileSize: 2_100_000, createdAt: Date.now.addingTimeInterval(-259200)),
        SinglePhoto(shade: 0.70, aspectRatio: 0.46, fileSize: 1_500_000, createdAt: Date.now.addingTimeInterval(-345600)),
        SinglePhoto(shade: 0.45, aspectRatio: 0.46, fileSize: 2_800_000, createdAt: Date.now.addingTimeInterval(-432000)),
        SinglePhoto(shade: 0.60, aspectRatio: 0.46, fileSize: 1_700_000, createdAt: Date.now.addingTimeInterval(-518400)),
        SinglePhoto(shade: 0.50, aspectRatio: 0.46, fileSize: 2_200_000, createdAt: Date.now.addingTimeInterval(-604800)),
        SinglePhoto(shade: 0.30, aspectRatio: 0.46, fileSize: 3_100_000, createdAt: Date.now.addingTimeInterval(-691200)),
        SinglePhoto(shade: 0.65, aspectRatio: 0.46, fileSize: 1_800_000, createdAt: Date.now.addingTimeInterval(-777600)),
    ]
}
