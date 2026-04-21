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

    /// 64-bit perceptual hash (pHash) — DCT-based. Resizes to 32×32 grayscale,
    /// applies 2D DCT via `vDSP`, extracts the 8×8 low-frequency block, and
    /// sets each bit according to whether that coefficient exceeds the mean
    /// of the block (excluding the DC term). pHash complements dHash: dHash
    /// is sensitive to gradient direction, pHash captures luminance structure
    /// across frequency bands. Requiring both to match tightly rules out
    /// burst-sibling false positives where one hash coincidentally agrees.
    static func pHash(_ cgImage: CGImage) -> UInt64 {
        let size = 32
        var pixels = [UInt8](repeating: 0, count: size * size)
        guard let context = CGContext(
            data: &pixels,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return 0 }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))

        let floats = pixels.map { Float($0) }
        guard let dct = vDSP.DCT(count: size, transformType: .II) else { return 0 }

        // 2D DCT: apply 1D DCT to each row, then to each column of the result.
        var rowsOut = [Float](repeating: 0, count: size * size)
        for row in 0..<size {
            let slice = Array(floats[(row * size)..<(row * size + size)])
            let out = dct.transform(slice)
            for col in 0..<size { rowsOut[row * size + col] = out[col] }
        }
        var dct2D = [Float](repeating: 0, count: size * size)
        for col in 0..<size {
            var column = [Float](repeating: 0, count: size)
            for row in 0..<size { column[row] = rowsOut[row * size + col] }
            let out = dct.transform(column)
            for row in 0..<size { dct2D[row * size + col] = out[row] }
        }

        // Top-left 8×8 low-frequency block.
        let block = 8
        var lowFreq = [Float](repeating: 0, count: block * block)
        for row in 0..<block {
            for col in 0..<block {
                lowFreq[row * block + col] = dct2D[row * size + col]
            }
        }

        // Mean of the block excluding the DC term at [0,0].
        let sum = lowFreq.reduce(0, +) - lowFreq[0]
        let mean = sum / Float(lowFreq.count - 1)

        var hash: UInt64 = 0
        for i in 0..<lowFreq.count where lowFreq[i] > mean {
            hash |= (UInt64(1) << i)
        }
        return hash
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
