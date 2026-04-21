import Foundation
import SwiftData

/// Distinguishes the two clustering tiers the scanner produces. Persisted as
/// a raw string on `DuplicateGroupRecord` so SwiftData lightweight-migrates
/// pre-existing stores without schema intervention.
enum DuplicateGroupKind: String, CaseIterable, Sendable {
    case exact      // dHash+pHash tight, burst siblings excluded
    case similar    // looser dHash, burst siblings included — requires human review
}

/// SwiftData row representing a cluster of visually-duplicate photos. The
/// `hashBucket` is the dHash of the cluster's first member, used as a stable
/// identifier for the group across re-scans.
@Model
final class DuplicateGroupRecord {
    var hashBucket: Int64
    var createdAt: Date
    /// `"exact"` for tight-match duplicates (dHash+pHash, no burst siblings)
    /// or `"similar"` for loose-match same-moment photos. Raw string so the
    /// schema is lightweight-migratable; use `DuplicateGroupKind` to read it.
    var kindRaw: String = DuplicateGroupKind.exact.rawValue

    @Relationship(deleteRule: .nullify, inverse: \ScannedAsset.duplicateGroup)
    var members: [ScannedAsset]

    init(
        hashBucket: UInt64,
        createdAt: Date = .now,
        kind: DuplicateGroupKind = .exact,
        members: [ScannedAsset] = []
    ) {
        self.hashBucket = Int64(bitPattern: hashBucket)
        self.createdAt = createdAt
        self.kindRaw = kind.rawValue
        self.members = members
    }

    var kind: DuplicateGroupKind {
        DuplicateGroupKind(rawValue: kindRaw) ?? .exact
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
