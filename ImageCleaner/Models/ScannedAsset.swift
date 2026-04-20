import Foundation
import SwiftData

/// SwiftData row for a single photo library asset we've already classified.
/// Lets subsequent scans skip the expensive pixel work when dimensions match.
@Model
final class ScannedAsset {
    @Attribute(.unique) var localIdentifier: String
    /// `UInt64` dHash round-tripped as `Int64` — SwiftData doesn't encode `UInt64` directly.
    var dHash: Int64
    var pixelWidth: Int
    var pixelHeight: Int
    var fileSize: Int64
    var createdAt: Date
    var isScreenshot: Bool
    var isBlank: Bool
    var brightness: Double
    var variance: Double
    var duplicateGroup: DuplicateGroupRecord?

    init(
        localIdentifier: String,
        dHash: UInt64,
        pixelWidth: Int,
        pixelHeight: Int,
        fileSize: Int64 = 0,
        createdAt: Date = .now,
        isScreenshot: Bool = false,
        isBlank: Bool = false,
        brightness: Double = 0,
        variance: Double = 0,
        duplicateGroup: DuplicateGroupRecord? = nil
    ) {
        self.localIdentifier = localIdentifier
        self.dHash = Int64(bitPattern: dHash)
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.fileSize = fileSize
        self.createdAt = createdAt
        self.isScreenshot = isScreenshot
        self.isBlank = isBlank
        self.brightness = brightness
        self.variance = variance
        self.duplicateGroup = duplicateGroup
    }

    /// Typed view of the raw `Int64`-backed hash.
    var dHashUnsigned: UInt64 {
        get { UInt64(bitPattern: dHash) }
        set { dHash = Int64(bitPattern: newValue) }
    }
}
