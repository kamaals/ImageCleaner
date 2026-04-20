import CoreGraphics
import CoreImage
import Accelerate

/// Pure image-analysis helpers used by `PhotoScanner`. Extracted so they can
/// be unit-tested against synthetic `CGImage`s without involving PhotoKit.
enum ImageAnalysis {
    /// 64-bit difference hash. Resizes `cgImage` to 9×8 grayscale, then for
    /// each of 64 cells sets a bit if pixel > right-neighbor. Tiny, stable,
    /// forgiving of cropping/compression — the classic dHash.
    static func dHash(_ cgImage: CGImage) -> UInt64 {
        let width = 9, height = 8
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return 0 }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var hash: UInt64 = 0
        for row in 0..<height {
            for col in 0..<(width - 1) {
                let left = pixels[row * width + col]
                let right = pixels[row * width + col + 1]
                if left > right {
                    hash |= (UInt64(1) << (row * (width - 1) + col))
                }
            }
        }
        return hash
    }

    /// Hamming distance (number of differing bits) between two dHashes.
    static func hamming(_ a: UInt64, _ b: UInt64) -> Int {
        (a ^ b).nonzeroBitCount
    }

    /// Mean brightness (0…1) plus the variance of brightness across an 8×8
    /// grid. The grid variance catches near-uniform images (blanks, solid
    /// colors) that still have some overall luminance.
    static func brightnessAndVariance(_ cgImage: CGImage) -> (brightness: Double, variance: Double) {
        let grid = 8
        let total = grid * grid
        var pixels = [UInt8](repeating: 0, count: total)
        guard let context = CGContext(
            data: &pixels,
            width: grid,
            height: grid,
            bitsPerComponent: 8,
            bytesPerRow: grid,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return (0, 0) }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: grid, height: grid))

        let normalized = pixels.map { Double($0) / 255.0 }
        let mean = normalized.reduce(0, +) / Double(total)
        let variance = normalized.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(total)
        return (mean, variance)
    }

    /// Greedy Hamming-distance clustering. Input is hash → id pairs; output
    /// is arrays of ids that share a cluster (size ≥ 2). Threshold default
    /// 5 mirrors the experiments' "near-identical" bucket.
    static func cluster<ID: Hashable>(
        hashes: [(id: ID, hash: UInt64)],
        threshold: Int = 5
    ) -> [[ID]] {
        var remaining = hashes
        var groups: [[ID]] = []

        while let seed = remaining.first {
            remaining.removeFirst()
            var cluster: [ID] = [seed.id]
            remaining.removeAll { candidate in
                if hamming(seed.hash, candidate.hash) <= threshold {
                    cluster.append(candidate.id)
                    return true
                }
                return false
            }
            if cluster.count >= 2 {
                groups.append(cluster)
            }
        }
        return groups
    }
}
