import Foundation
import SwiftUI

/// Represents a single photo within a duplicate group
struct DuplicateImage: Identifiable, Equatable {
    let id: UUID
    /// PhotoKit asset identifier when backed by a real photo; `nil` for mocks.
    let localIdentifier: String?
    let shade: Double // For mock data visualization
    let fileSize: Int64 // Size in bytes
    let createdAt: Date

    init(id: UUID = UUID(), localIdentifier: String? = nil, shade: Double, fileSize: Int64, createdAt: Date = .now) {
        self.id = id
        self.localIdentifier = localIdentifier
        self.shade = shade
        self.fileSize = fileSize
        self.createdAt = createdAt
    }
    
    /// Formatted file size string
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

/// Represents a group of duplicate photos
struct DuplicatePhoto: Identifiable, Equatable {
    let id: UUID
    let displayHeight: CGFloat // For waterfall grid
    var images: [DuplicateImage] // The duplicate images (2 or 3)
    var isSelected: Bool
    
    init(id: UUID = UUID(), displayHeight: CGFloat, images: [DuplicateImage], isSelected: Bool = false) {
        self.id = id
        self.displayHeight = displayHeight
        self.images = images
        self.isSelected = isSelected
    }
    
    /// Number of duplicates in this group
    var duplicateCount: Int {
        images.count
    }
    
    /// The primary image shade for display in the grid
    var primaryShade: Double {
        images.first?.shade ?? 0.5
    }
    
    /// Total size of all duplicates
    var totalSize: Int64 {
        images.reduce(0) { $0 + $1.fileSize }
    }
    
    /// Formatted total size string
    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    /// Whether we can delete more images (must keep at least 1)
    var canDeleteMore: Bool {
        images.count > 1
    }
    
    /// Mock data for preview and testing
    static let mockData: [DuplicatePhoto] = [
        DuplicatePhoto(
            displayHeight: 180,
            images: [
                DuplicateImage(shade: 0.5, fileSize: 2_500_000, createdAt: Date.now.addingTimeInterval(-86400)),
                DuplicateImage(shade: 0.55, fileSize: 2_480_000, createdAt: Date.now.addingTimeInterval(-86000))
            ]
        ),
        DuplicatePhoto(
            displayHeight: 120,
            images: [
                DuplicateImage(shade: 0.85, fileSize: 1_800_000, createdAt: Date.now.addingTimeInterval(-172800)),
                DuplicateImage(shade: 0.8, fileSize: 1_750_000, createdAt: Date.now.addingTimeInterval(-172000)),
                DuplicateImage(shade: 0.82, fileSize: 1_820_000, createdAt: Date.now.addingTimeInterval(-171000))
            ]
        ),
        DuplicatePhoto(
            displayHeight: 160,
            images: [
                DuplicateImage(shade: 0.6, fileSize: 3_200_000, createdAt: Date.now.addingTimeInterval(-259200)),
                DuplicateImage(shade: 0.65, fileSize: 3_150_000, createdAt: Date.now.addingTimeInterval(-259000)),
                DuplicateImage(shade: 0.55, fileSize: 3_250_000, createdAt: Date.now.addingTimeInterval(-258800))
            ]
        ),
        DuplicatePhoto(
            displayHeight: 100,
            images: [
                DuplicateImage(shade: 0.7, fileSize: 980_000, createdAt: Date.now.addingTimeInterval(-345600)),
                DuplicateImage(shade: 0.75, fileSize: 950_000, createdAt: Date.now.addingTimeInterval(-345000))
            ]
        ),
        DuplicatePhoto(
            displayHeight: 200,
            images: [
                DuplicateImage(shade: 0.45, fileSize: 4_500_000, createdAt: Date.now.addingTimeInterval(-432000)),
                DuplicateImage(shade: 0.5, fileSize: 4_450_000, createdAt: Date.now.addingTimeInterval(-431500))
            ]
        ),
        DuplicatePhoto(
            displayHeight: 140,
            images: [
                DuplicateImage(shade: 0.55, fileSize: 2_100_000, createdAt: Date.now.addingTimeInterval(-518400)),
                DuplicateImage(shade: 0.6, fileSize: 2_050_000, createdAt: Date.now.addingTimeInterval(-518000)),
                DuplicateImage(shade: 0.52, fileSize: 2_150_000, createdAt: Date.now.addingTimeInterval(-517500))
            ]
        ),
        DuplicatePhoto(
            displayHeight: 80,
            images: [
                DuplicateImage(shade: 0.75, fileSize: 750_000, createdAt: Date.now.addingTimeInterval(-604800)),
                DuplicateImage(shade: 0.7, fileSize: 720_000, createdAt: Date.now.addingTimeInterval(-604000))
            ]
        ),
        DuplicatePhoto(
            displayHeight: 220,
            images: [
                DuplicateImage(shade: 0.5, fileSize: 5_200_000, createdAt: Date.now.addingTimeInterval(-691200)),
                DuplicateImage(shade: 0.45, fileSize: 5_150_000, createdAt: Date.now.addingTimeInterval(-690500))
            ]
        ),
        DuplicatePhoto(
            displayHeight: 110,
            images: [
                DuplicateImage(shade: 0.65, fileSize: 1_400_000, createdAt: Date.now.addingTimeInterval(-777600)),
                DuplicateImage(shade: 0.6, fileSize: 1_350_000, createdAt: Date.now.addingTimeInterval(-777000)),
                DuplicateImage(shade: 0.68, fileSize: 1_420_000, createdAt: Date.now.addingTimeInterval(-776500))
            ]
        ),
        DuplicatePhoto(
            displayHeight: 170,
            images: [
                DuplicateImage(shade: 0.4, fileSize: 3_800_000, createdAt: Date.now.addingTimeInterval(-864000)),
                DuplicateImage(shade: 0.45, fileSize: 3_750_000, createdAt: Date.now.addingTimeInterval(-863500))
            ]
        ),
        DuplicatePhoto(
            displayHeight: 130,
            images: [
                DuplicateImage(shade: 0.8, fileSize: 1_600_000, createdAt: Date.now.addingTimeInterval(-950400)),
                DuplicateImage(shade: 0.75, fileSize: 1_550_000, createdAt: Date.now.addingTimeInterval(-949900))
            ]
        ),
        DuplicatePhoto(
            displayHeight: 150,
            images: [
                DuplicateImage(shade: 0.35, fileSize: 2_800_000, createdAt: Date.now.addingTimeInterval(-1036800)),
                DuplicateImage(shade: 0.4, fileSize: 2_750_000, createdAt: Date.now.addingTimeInterval(-1036200)),
                DuplicateImage(shade: 0.38, fileSize: 2_820_000, createdAt: Date.now.addingTimeInterval(-1035600))
            ]
        ),
        DuplicatePhoto(
            displayHeight: 90,
            images: [
                DuplicateImage(shade: 0.55, fileSize: 890_000, createdAt: Date.now.addingTimeInterval(-1123200)),
                DuplicateImage(shade: 0.5, fileSize: 860_000, createdAt: Date.now.addingTimeInterval(-1122600))
            ]
        ),
        DuplicatePhoto(
            displayHeight: 180,
            images: [
                DuplicateImage(shade: 0.45, fileSize: 4_100_000, createdAt: Date.now.addingTimeInterval(-1209600)),
                DuplicateImage(shade: 0.5, fileSize: 4_050_000, createdAt: Date.now.addingTimeInterval(-1209000))
            ]
        ),
        DuplicatePhoto(
            displayHeight: 120,
            images: [
                DuplicateImage(shade: 0.7, fileSize: 1_500_000, createdAt: Date.now.addingTimeInterval(-1296000)),
                DuplicateImage(shade: 0.65, fileSize: 1_450_000, createdAt: Date.now.addingTimeInterval(-1295400)),
                DuplicateImage(shade: 0.72, fileSize: 1_520_000, createdAt: Date.now.addingTimeInterval(-1294800))
            ]
        ),
    ]
}
