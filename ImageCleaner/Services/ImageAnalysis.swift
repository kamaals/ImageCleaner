import CoreGraphics
import CoreImage
import Accelerate

/// Pure image-analysis helpers used by `PhotoScanner`. Extracted so they can
/// be unit-tested against synthetic `CGImage`s without involving PhotoKit.
///
/// `nonisolated` because these are pure functions called from the `PhotoScanner`
/// actor and other nonisolated contexts; without it the project's
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` setting would infer `@MainActor`
/// on every member and make them unreachable off the main actor.
nonisolated enum ImageAnalysis {
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

    /// Mean brightness (0…1) plus the variance of per-cell brightness across a
    /// 64×64 grayscale grid.
    ///
    /// The fine grid is deliberate. A coarse grid (the previous 8×8) averages
    /// text and edges away, so a document or screenshot reads as near-uniform
    /// and gets misclassified as blank. At 64×64 real content produces real
    /// variance, while a genuinely solid image stays near zero at any resolution.
    static func brightnessAndVariance(_ cgImage: CGImage) -> (brightness: Double, variance: Double) {
        let grid = 64
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

    /// Whether `variance` (from `brightnessAndVariance`) marks the image as a
    /// "blank" — i.e. a near-solid image, the same colour across every pixel.
    ///
    /// The test is on the standard deviation (√variance): the image is blank
    /// when its brightness deviates from flat by no more than `stdCeiling`.
    /// Default `0.02` accepts 2% deviation, so genuine solid-colour shots
    /// (all-black, all-white, an accidental solid frame) qualify while anything
    /// with real content — text, a subject, a gradient — does not. Hue is
    /// ignored: the analysis is grayscale, so any single solid colour reads as
    /// uniform.
    static func isBlank(variance: Double, stdCeiling: Double = 0.02) -> Bool {
        variance.squareRoot() <= stdCeiling
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
