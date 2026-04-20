import Foundation
import SwiftData

/// SwiftData row representing a cluster of visually-duplicate photos. The
/// `hashBucket` is the dHash of the cluster's first member, used as a stable
/// identifier for the group across re-scans.
@Model
final class DuplicateGroupRecord {
    var hashBucket: Int64
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \ScannedAsset.duplicateGroup)
    var members: [ScannedAsset]

    init(
        hashBucket: UInt64,
        createdAt: Date = .now,
        members: [ScannedAsset] = []
    ) {
        self.hashBucket = Int64(bitPattern: hashBucket)
        self.createdAt = createdAt
        self.members = members
    }

    var hashBucketUnsigned: UInt64 {
        UInt64(bitPattern: hashBucket)
    }

    /// Bytes reclaimable if we kept only the largest member.
    var reclaimableBytes: Int64 {
        guard let biggest = members.max(by: { $0.fileSize < $1.fileSize }) else {
            return 0
        }
        return members.reduce(0) { $0 + $1.fileSize } - biggest.fileSize
    }
}
