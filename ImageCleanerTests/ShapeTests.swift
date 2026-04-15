import Testing
import SwiftUI
@testable import ImageCleaner

/// Tests for pure-geometry custom Shapes. Path is checked for emptiness or
/// presence of content rather than pixel-exact equality (the latter is brittle
/// across SwiftUI versions). Each Shape's `animatableData` getter/setter is
/// also exercised so the conformance round-trips correctly.
struct ShapeTests {
    private let rect = CGRect(x: 0, y: 0, width: 100, height: 100)

    // MARK: - LCutShape

    @Test func lCutShapeAtZeroTrimReturnsEmptyPath() {
        let shape = LCutShape(
            trimEnd: 0,
            startPoint: CGPoint(x: 0, y: 0),
            cornerPoint: CGPoint(x: 50, y: 50),
            endPoint: CGPoint(x: 100, y: 50)
        )
        #expect(shape.path(in: rect).isEmpty)
    }

    @Test func lCutShapeAtFullTrimDrawsTwoSegments() {
        let shape = LCutShape(
            trimEnd: 1,
            startPoint: CGPoint(x: 0, y: 0),
            cornerPoint: CGPoint(x: 50, y: 50),
            endPoint: CGPoint(x: 100, y: 50)
        )
        let path = shape.path(in: rect)
        #expect(!path.isEmpty)
        // The bounding rect should span from start (0,0) to end (100,50)
        #expect(path.boundingRect.maxX >= 99)
        #expect(path.boundingRect.maxY >= 49)
    }

    @Test func lCutShapeMidTrimDrawsOnlyFirstSegment() {
        // First segment length: |50-0|+|50-0| = 100; second segment length: |100-50|+|50-50| = 50
        // Total length: 150. trimEnd = 0.5 → drawn = 75pt, which is within first segment
        let shape = LCutShape(
            trimEnd: 0.5,
            startPoint: CGPoint(x: 0, y: 0),
            cornerPoint: CGPoint(x: 50, y: 50),
            endPoint: CGPoint(x: 100, y: 50)
        )
        let path = shape.path(in: rect)
        #expect(!path.isEmpty)
        // Path should not extend past the corner point
        #expect(path.boundingRect.maxX <= 50)
    }

    @Test func lCutShapeAnimatableDataRoundTrips() {
        var shape = LCutShape(
            trimEnd: 0.3,
            startPoint: .zero,
            cornerPoint: CGPoint(x: 1, y: 1),
            endPoint: CGPoint(x: 2, y: 1)
        )
        #expect(shape.animatableData == 0.3)
        shape.animatableData = 0.7
        #expect(shape.trimEnd == 0.7)
    }

    @Test func lCutShapeWithDegenerateGeometryReturnsEmpty() {
        // start == corner == end → totalLen = 0 → guard triggers
        let shape = LCutShape(
            trimEnd: 1,
            startPoint: .zero,
            cornerPoint: .zero,
            endPoint: .zero
        )
        #expect(shape.path(in: rect).isEmpty)
    }

    // MARK: - HorizontalLinesShape

    @Test func horizontalLinesAtZeroGrowthIsEmpty() {
        let shape = HorizontalLinesShape(growth: 0, groupSpacing: 20, yStart: 0)
        #expect(shape.path(in: rect).isEmpty)
    }

    @Test func horizontalLinesAtFullGrowthHasContent() {
        let shape = HorizontalLinesShape(growth: 1, groupSpacing: 20, yStart: 0)
        let path = shape.path(in: rect)
        #expect(!path.isEmpty)
    }

    @Test func horizontalLinesAnimatableDataRoundTrips() {
        var shape = HorizontalLinesShape(growth: 0.4, groupSpacing: 10, yStart: 0)
        #expect(shape.animatableData == 0.4)
        shape.animatableData = 0.9
        #expect(shape.growth == 0.9)
    }

    // MARK: - DiagonalLinesShape

    @Test func diagonalLinesAtZeroGrowthIsEmpty() {
        let shape = DiagonalLinesShape(growth: 0, spacing: 20)
        #expect(shape.path(in: rect).isEmpty)
    }

    @Test func diagonalLinesAtFullGrowthHasContent() {
        let shape = DiagonalLinesShape(growth: 1, spacing: 20)
        let path = shape.path(in: rect)
        #expect(!path.isEmpty)
    }

    @Test func diagonalLinesAnimatableDataRoundTrips() {
        var shape = DiagonalLinesShape(growth: 0.25, spacing: 15)
        #expect(shape.animatableData == 0.25)
        shape.animatableData = 0.75
        #expect(shape.growth == 0.75)
    }
}
