import Testing
import CoreGraphics
import CoreImage
@testable import ImageCleaner

struct ImageAnalysisTests {
    // MARK: - Synthetic image helpers

    /// Makes a solid-color gray CGImage (width×height). Used for blank/black tests.
    private func solidGray(_ value: UInt8, size: Int = 32) -> CGImage {
        let total = size * size
        let pixels = [UInt8](repeating: value, count: total)
        return pixels.withUnsafeBytes { raw in
            let provider = CGDataProvider(
                data: Data(raw) as CFData
            )!
            return CGImage(
                width: size, height: size,
                bitsPerComponent: 8, bitsPerPixel: 8,
                bytesPerRow: size,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider, decode: nil,
                shouldInterpolate: false, intent: .defaultIntent
            )!
        }
    }

    /// Makes a checkerboard. Used to get a non-trivial dHash and high variance.
    private func checker(size: Int = 32, cell: Int = 4) -> CGImage {
        var pixels = [UInt8](repeating: 0, count: size * size)
        for y in 0..<size {
            for x in 0..<size {
                let on = ((x / cell) + (y / cell)) % 2 == 0
                pixels[y * size + x] = on ? 255 : 0
            }
        }
        return pixels.withUnsafeBytes { raw in
            let provider = CGDataProvider(data: Data(raw) as CFData)!
            return CGImage(
                width: size, height: size,
                bitsPerComponent: 8, bitsPerPixel: 8,
                bytesPerRow: size,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider, decode: nil,
                shouldInterpolate: false, intent: .defaultIntent
            )!
        }
    }

    /// Light background with thin dark horizontal lines — stands in for a text
    /// document or screenshot. Mostly one colour, but with real high-frequency
    /// content, so a correct blank detector must NOT classify it as blank. This
    /// is the exact shape that a coarse 8×8 grid averaged into "uniform".
    private func documentLike(size: Int = 64, lineEvery: Int = 8) -> CGImage {
        var pixels = [UInt8](repeating: 240, count: size * size)
        for y in stride(from: 2, to: size, by: lineEvery) {
            for x in 0..<size { pixels[y * size + x] = 20 }
        }
        return pixels.withUnsafeBytes { raw in
            let provider = CGDataProvider(data: Data(raw) as CFData)!
            return CGImage(
                width: size, height: size,
                bitsPerComponent: 8, bitsPerPixel: 8,
                bytesPerRow: size,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider, decode: nil,
                shouldInterpolate: false, intent: .defaultIntent
            )!
        }
    }

    /// Mostly-black frame with a centred bright block — stands in for a dark
    /// photo with a subject (silhouette, neon sign). Not uniform → not blank.
    private func darkWithSubject(size: Int = 64) -> CGImage {
        var pixels = [UInt8](repeating: 0, count: size * size)
        let lo = size / 4, hi = size * 3 / 4
        for y in lo..<hi { for x in lo..<hi { pixels[y * size + x] = 255 } }
        return pixels.withUnsafeBytes { raw in
            let provider = CGDataProvider(data: Data(raw) as CFData)!
            return CGImage(
                width: size, height: size,
                bitsPerComponent: 8, bitsPerPixel: 8,
                bytesPerRow: size,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider, decode: nil,
                shouldInterpolate: false, intent: .defaultIntent
            )!
        }
    }

    // MARK: - dHash

    @Test func dHashOfSolidImageIsZero() {
        // With a flat image every "left > right" test is false → all zero bits.
        let hash = ImageAnalysis.dHash(solidGray(128))
        #expect(hash == 0)
    }

    @Test func dHashIsDeterministic() {
        let image = checker()
        #expect(ImageAnalysis.dHash(image) == ImageAnalysis.dHash(image))
    }

    @Test func dHashDistinguishesVerySimilarImages() {
        let a = solidGray(0)
        let b = checker()
        #expect(ImageAnalysis.dHash(a) != ImageAnalysis.dHash(b))
    }

    // MARK: - Hamming

    @Test func hammingOfIdenticalHashesIsZero() {
        #expect(ImageAnalysis.hamming(0xDEADBEEF, 0xDEADBEEF) == 0)
    }

    @Test func hammingCountsDifferingBits() {
        #expect(ImageAnalysis.hamming(0b0000, 0b1111) == 4)
        #expect(ImageAnalysis.hamming(0b1010, 0b0101) == 4)
    }

    // MARK: - Brightness + variance

    @Test func brightnessOfBlackImageIsNearZero() {
        let (brightness, variance) = ImageAnalysis.brightnessAndVariance(solidGray(0))
        #expect(brightness < 0.01)
        #expect(variance < 0.001)
    }

    @Test func brightnessOfWhiteImageIsNearOne() {
        let (brightness, _) = ImageAnalysis.brightnessAndVariance(solidGray(255))
        #expect(brightness > 0.99)
    }

    @Test func varianceOfFlatImageIsNearZero() {
        let (_, variance) = ImageAnalysis.brightnessAndVariance(solidGray(128))
        #expect(variance < 0.001)
    }

    @Test func varianceOfCheckerIsHigh() {
        let (_, variance) = ImageAnalysis.brightnessAndVariance(checker(cell: 4))
        #expect(variance > 0.05)
    }

    // MARK: - Blank detection (solid colour = blank, real content = not blank)

    @Test func solidImagesOfAnyToneAreBlank() {
        for tone: UInt8 in [0, 64, 128, 200, 255] {
            let (_, variance) = ImageAnalysis.brightnessAndVariance(solidGray(tone))
            #expect(ImageAnalysis.isBlank(variance: variance), "solid \(tone) should be blank")
        }
    }

    @Test func documentLikeImageIsNotBlank() {
        // Regression: a sparse-content document collapsed to a near-uniform 8×8
        // grid and was wrongly flagged blank. At full resolution its variance is
        // well above the blank threshold.
        let (_, variance) = ImageAnalysis.brightnessAndVariance(documentLike())
        #expect(variance > 0.0004)
        #expect(!ImageAnalysis.isBlank(variance: variance))
    }

    @Test func darkPhotoWithSubjectIsNotBlank() {
        let (_, variance) = ImageAnalysis.brightnessAndVariance(darkWithSubject())
        #expect(!ImageAnalysis.isBlank(variance: variance))
    }

    @Test func isBlankAcceptsUpToTwoPercentDeviation() {
        // √variance is the standard deviation; the ceiling is 2%.
        #expect(ImageAnalysis.isBlank(variance: 0.019 * 0.019))  // 1.9% std → blank
        #expect(!ImageAnalysis.isBlank(variance: 0.03 * 0.03))   // 3% std → not blank
    }

    // MARK: - cluster

    @Test func clusterGroupsHashesWithinThreshold() {
        // Two hashes differing by 1 bit → same cluster.
        // Third hash differing by ~32 bits → separate, excluded (singleton).
        let a: UInt64 = 0x00
        let b: UInt64 = 0x01
        let c: UInt64 = 0xFFFFFFFF
        let groups = ImageAnalysis.cluster(
            hashes: [("a", a), ("b", b), ("c", c)],
            threshold: 5
        )
        #expect(groups.count == 1)
        #expect(groups[0].sorted() == ["a", "b"])
    }

    @Test func clusterReturnsNoGroupsWhenNothingMatches() {
        let groups = ImageAnalysis.cluster(
            hashes: [("a", 0x00), ("b", UInt64.max)],
            threshold: 5
        )
        #expect(groups.isEmpty)
    }

    @Test func clusterCanProduceMultipleGroups() {
        // Two tight pairs, each far from the other pair.
        let groups = ImageAnalysis.cluster(
            hashes: [
                ("a", 0x0000_0000_0000_0000),
                ("b", 0x0000_0000_0000_0001),
                ("c", 0xFFFF_FFFF_FFFF_FFFF),
                ("d", 0xFFFF_FFFF_FFFF_FFFE),
            ],
            threshold: 5
        )
        #expect(groups.count == 2)
    }
}
