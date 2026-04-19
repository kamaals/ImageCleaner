import Testing
import SwiftUI
@testable import ImageCleaner

/// Tests for `FrontBlackPath` and `FrontWhitePath` — the segmented border
/// shapes used by `AppIconView` to two-tone the front square's outline
/// where it overlaps the back square.
struct FrontPathShapeTests {
    private let rect = CGRect(x: 0, y: 0, width: 200, height: 200)

    // MARK: - FrontBlackPath

    @Test func frontBlackPathDrawsNonEmptyWithValidGeometry() {
        let shape = FrontBlackPath(squareSide: 100, crossX: 20, crossY: 80)
        #expect(!shape.path(in: rect).isEmpty)
    }

    @Test func frontBlackPathBoundingBoxSpansTheSquare() {
        let shape = FrontBlackPath(squareSide: 100, crossX: 20, crossY: 80)
        let bounds = shape.path(in: rect).boundingRect
        // Right edge (squareSide) and top edge (y=0) are always drawn
        #expect(bounds.maxX == 100)
        #expect(bounds.minY == 0)
    }

    @Test func frontBlackPathClampsCrossPointsToSquareBounds() {
        // crossX > squareSide and crossY > squareSide should be clamped to squareSide
        let shape = FrontBlackPath(squareSide: 100, crossX: 999, crossY: 999)
        let bounds = shape.path(in: rect).boundingRect
        #expect(bounds.maxX <= 100)
        #expect(bounds.maxY <= 100)
    }

    @Test func frontBlackPathClampsNegativeCrossPointsToZero() {
        let shape = FrontBlackPath(squareSide: 100, crossX: -50, crossY: -50)
        let bounds = shape.path(in: rect).boundingRect
        #expect(bounds.minX >= 0)
        #expect(bounds.minY >= 0)
    }

    @Test func frontBlackPathAnimatableDataRoundTrips() {
        var shape = FrontBlackPath(squareSide: 100, crossX: 20, crossY: 80)
        let data = shape.animatableData
        #expect(data.first == 100)
        #expect(data.second.first == 20)
        #expect(data.second.second == 80)

        shape.animatableData = .init(50, .init(10, 40))
        #expect(shape.squareSide == 50)
        #expect(shape.crossX == 10)
        #expect(shape.crossY == 40)
    }

    // MARK: - FrontWhitePath

    @Test func frontWhitePathDrawsNonEmptyWithValidGeometry() {
        let shape = FrontWhitePath(squareSide: 100, crossX: 20, crossY: 80)
        #expect(!shape.path(in: rect).isEmpty)
    }

    @Test func frontWhitePathStaysOnLowerLeftEdges() {
        // White path draws: crossX on bottom → bottom-left → crossY on left.
        // It should never exceed squareSide / 2 horizontally for moderate cross points
        // and should touch the bottom edge (y == squareSide).
        let shape = FrontWhitePath(squareSide: 100, crossX: 30, crossY: 70)
        let bounds = shape.path(in: rect).boundingRect
        #expect(bounds.maxY == 100) // bottom edge touched
        #expect(bounds.minX == 0) // left edge touched
    }

    @Test func frontWhitePathClampsCrossPoints() {
        let shape = FrontWhitePath(squareSide: 100, crossX: -10, crossY: 500)
        let bounds = shape.path(in: rect).boundingRect
        #expect(bounds.minX >= 0)
        #expect(bounds.maxY <= 100)
    }

    @Test func frontWhitePathAnimatableDataRoundTrips() {
        var shape = FrontWhitePath(squareSide: 100, crossX: 20, crossY: 80)
        #expect(shape.animatableData.first == 100)

        shape.animatableData = .init(75, .init(25, 50))
        #expect(shape.squareSide == 75)
        #expect(shape.crossX == 25)
        #expect(shape.crossY == 50)
    }
}
