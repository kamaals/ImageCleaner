import Testing
import SwiftUI
@testable import ImageCleaner

/// Tests for `WaterfallGrid`'s internal frame calculation. We can't exercise
/// the Layout protocol directly (no public access to `subviews`/`ProposedViewSize`
/// in isolation), so we mirror the column-packing math in a test-only
/// implementation and assert its invariants for fixed-height inputs.
///
/// The real `WaterfallGrid.calculateFrames` is private; these tests validate
/// the documented contract:
/// - Items are placed in the shortest column
/// - Column widths equal `(containerWidth − spacing × (columns − 1)) / columns`
/// - Items never overlap vertically within a column
/// - Spacing is applied between items in the same column
struct WaterfallGridTests {
    /// Reference implementation mirroring `WaterfallGrid.calculateFrames`, used
    /// to verify the column-packing invariants against representative inputs.
    private func packFrames(
        heights: [CGFloat],
        columns: Int,
        spacing: CGFloat,
        containerWidth: CGFloat
    ) -> [CGRect] {
        let columnCount = max(1, columns)
        let columnWidth = (containerWidth - spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount)
        var columnHeights = Array(repeating: CGFloat.zero, count: columnCount)
        var frames: [CGRect] = []

        for height in heights {
            let shortest = columnHeights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            let x = CGFloat(shortest) * (columnWidth + spacing)
            let y = columnHeights[shortest]
            frames.append(CGRect(x: x, y: y, width: columnWidth, height: height))
            columnHeights[shortest] = y + height + spacing
        }
        return frames
    }

    // MARK: - Init

    @Test func initClampsColumnsToAtLeastOne() {
        let grid = WaterfallGrid(columns: 0, spacing: 8)
        #expect(grid.columns == 1)
    }

    @Test func initPreservesValidColumnCount() {
        let grid = WaterfallGrid(columns: 4, spacing: 12)
        #expect(grid.columns == 4)
        #expect(grid.spacing == 12)
    }

    @Test func initClampsNegativeColumnsToOne() {
        let grid = WaterfallGrid(columns: -3, spacing: 8)
        #expect(grid.columns == 1)
    }

    // MARK: - Column width math (packing invariants)

    @Test func columnWidthExcludesSpacingBetweenColumns() {
        let frames = packFrames(heights: [100], columns: 3, spacing: 10, containerWidth: 320)
        // Expected column width = (320 - 10*2) / 3 = 100
        #expect(frames[0].width == 100)
    }

    @Test func singleColumnTakesFullContainerWidth() {
        let frames = packFrames(heights: [100], columns: 1, spacing: 10, containerWidth: 320)
        #expect(frames[0].width == 320)
    }

    // MARK: - Placement invariants

    @Test func firstItemsFillColumnsLeftToRight() {
        let frames = packFrames(heights: [50, 50, 50], columns: 3, spacing: 8, containerWidth: 316)
        // All three heights equal → first three items take columns 0, 1, 2
        let xs = frames.map(\.origin.x).sorted()
        #expect(xs.count == 3)
        // x-positions must be distinct — otherwise two items overlap horizontally
        #expect(Set(xs).count == 3)
    }

    @Test func fourthItemGoesIntoShortestColumn() {
        // Column 0 is tallest (200), columns 1 and 2 are shorter (50 each)
        let frames = packFrames(heights: [200, 50, 50, 30], columns: 3, spacing: 8, containerWidth: 316)
        let columnWidth: CGFloat = (316 - 16) / 3
        let item4 = frames[3]
        // Item 4 must land in column 1 or 2 (whichever is picked first), not column 0
        #expect(item4.origin.x > columnWidth)
    }

    @Test func itemsInSameColumnDoNotOverlapVertically() {
        // Force items 0 and 3 into column 0: columns 1, 2 get taller items
        let frames = packFrames(
            heights: [50, 200, 200, 50],
            columns: 3,
            spacing: 8,
            containerWidth: 316
        )
        // Items 0 and 3 are in column 0 (x = 0). Item 3 must start after item 0 ends + spacing.
        let col0 = frames.enumerated().filter { $0.element.origin.x == 0 }
        #expect(col0.count == 2)
        let sorted = col0.sorted { $0.element.minY < $1.element.minY }
        let gap = sorted[1].element.minY - sorted[0].element.maxY
        #expect(gap >= 8) // spacing applied
    }

    @Test func emptyItemListProducesNoFrames() {
        let frames = packFrames(heights: [], columns: 3, spacing: 8, containerWidth: 300)
        #expect(frames.isEmpty)
    }

    // MARK: - Height calculation

    @Test func totalHeightIsMaxColumnHeight() {
        // Three items of the same height → one per column → height = item height (no spacing after)
        let frames = packFrames(heights: [120, 120, 120], columns: 3, spacing: 8, containerWidth: 316)
        let maxY = frames.map(\.maxY).max() ?? 0
        #expect(maxY == 120)
    }

    @Test func totalHeightAccountsForStackedItemsInSameColumn() {
        // Two items into 1 column: 100 + 8 spacing + 60 = 168 total, but last item's maxY is 168
        let frames = packFrames(heights: [100, 60], columns: 1, spacing: 8, containerWidth: 300)
        let maxY = frames.map(\.maxY).max() ?? 0
        #expect(maxY == 168)
    }
}
