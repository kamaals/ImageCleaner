import Foundation
import SwiftData

/// SwiftData row for a single photo library asset we've already classified.
/// Lets subsequent scans skip the expensive pixel work when dimensions match.
@Model
final class ScannedAsset {
    @Attribute(.unique) var localIdentifier: String
    /// `UInt64` dHash round-tripped as `Int64` — SwiftData doesn't encode `UInt64` directly.
    var dHash: Int64
    /// `UInt64` pHash round-tripped as `Int64`. Zero when the asset came from
    /// a pre-pHash scan and hasn't been re-analyzed yet.
    var pHash: Int64 = 0
    var pixelWidth: Int
    var pixelHeight: Int
    var fileSize: Int64
    var createdAt: Date
    var isScreenshot: Bool
    var isBlank: Bool
    var brightness: Double
    var variance: Double
    /// PhotoKit's burst group id, if any. Same value across all burst
    /// siblings; used to exclude them from exact-duplicate clustering.
    var burstIdentifier: String?
    var duplicateGroup: DuplicateGroupRecord?

    init(
        localIdentifier: String,
        dHash: UInt64,
        pHash: UInt64 = 0,
        pixelWidth: Int,
        pixelHeight: Int,
        fileSize: Int64 = 0,
        createdAt: Date = .now,
        isScreenshot: Bool = false,
        isBlank: Bool = false,
        brightness: Double = 0,
        variance: Double = 0,
        burstIdentifier: String? = nil,
        duplicateGroup: DuplicateGroupRecord? = nil
    ) {
        self.localIdentifier = localIdentifier
        self.dHash = Int64(bitPattern: dHash)
        self.pHash = Int64(bitPattern: pHash)
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.fileSize = fileSize
        self.createdAt = createdAt
        self.isScreenshot = isScreenshot
        self.isBlank = isBlank
        self.brightness = brightness
        self.variance = variance
        self.burstIdentifier = burstIdentifier
        self.duplicateGroup = duplicateGroup
    }

    /// Typed view of the raw `Int64`-backed dHash.
    var dHashUnsigned: UInt64 {
        get { UInt64(bitPattern: dHash) }
        set { dHash = Int64(bitPattern: newValue) }
    }

    /// Typed view of the raw `Int64`-backed pHash.
    var pHashUnsigned: UInt64 {
        get { UInt64(bitPattern: pHash) }
        set { pHash = Int64(bitPattern: newValue) }
    }
}
