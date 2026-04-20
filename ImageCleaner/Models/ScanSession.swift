import Foundation
import SwiftData

/// Metadata record for one completed (or in-progress) scan. Only the most
/// recent session is kept — on a new scan we delete older sessions after
/// persisting the new one.
@Model
final class ScanSession {
    var startedAt: Date
    var completedAt: Date?
    var totalScanned: Int
    /// Count of duplicate **groups**, not individual duplicate photos.
    var duplicateGroupCount: Int
    var screenshotCount: Int
    var blankCount: Int
    /// Bytes recoverable if the user clears all duplicates + screenshots + blanks.
    var reclaimableBytes: Int64

    init(
        startedAt: Date = .now,
        completedAt: Date? = nil,
        totalScanned: Int = 0,
        duplicateGroupCount: Int = 0,
        screenshotCount: Int = 0,
        blankCount: Int = 0,
        reclaimableBytes: Int64 = 0
    ) {
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.totalScanned = totalScanned
        self.duplicateGroupCount = duplicateGroupCount
        self.screenshotCount = screenshotCount
        self.blankCount = blankCount
        self.reclaimableBytes = reclaimableBytes
    }

    var isComplete: Bool { completedAt != nil }
}
