import SwiftUI

/// Pinterest-style waterfall grid with lazy per-column rendering.
///
/// Each item is assigned to the shortest running column based on its aspect
/// ratio and sized with an explicit `.frame(width:height:)` so SwiftUI never
/// has to infer the cell size from modifier order. That explicit sizing is
/// the key difference from a naive `.aspectRatio(_, .fit)` approach — inside
/// a `LazyVStack` that collapses flexible cells to square.
///
/// The available width is measured from a non-participating `GeometryReader`
/// in the background, so the grid composes naturally inside a `ScrollView`
/// (it sizes to its content, not to the scroll view's infinite height).
///
///     PinterestGrid(items: photos, columns: 2, spacing: 8, aspectRatio: { $0.aspectRatio }) { photo in
///         PhotoCell(photo: photo)
///     }
struct PinterestGrid<Item: Identifiable & Equatable, Cell: View>: View {
    let items: [Item]
    let columns: Int
    let spacing: CGFloat
    let aspectRatio: (Item) -> Double
    @ViewBuilder let cell: (Item) -> Cell

    @State private var availableWidth: CGFloat = 0

    init(
        items: [Item],
        columns: Int = 2,
        spacing: CGFloat = 8,
        aspectRatio: @escaping (Item) -> Double,
        @ViewBuilder cell: @escaping (Item) -> Cell
    ) {
        self.items = items
        self.columns = max(1, columns)
        self.spacing = spacing
        self.aspectRatio = aspectRatio
        self.cell = cell
    }

    var body: some View {
        let totalSpacing = spacing * CGFloat(columns - 1)
        let columnWidth = max(1, (availableWidth - totalSpacing) / CGFloat(columns))
        let assignments = distribute(items, into: columns)

        HStack(alignment: .top, spacing: spacing) {
            ForEach(0..<columns, id: \.self) { columnIndex in
                LazyVStack(spacing: spacing) {
                    ForEach(assignments[columnIndex]) { item in
                        let ratio = max(0.1, aspectRatio(item))
                        cell(item)
                            .frame(width: columnWidth, height: columnWidth / ratio)
                            .clipped()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: GridWidthKey.self, value: geo.size.width)
            }
        )
        .onPreferenceChange(GridWidthKey.self) { new in
            if new > 0, abs(new - availableWidth) > 0.5 {
                availableWidth = new
            }
        }
    }

    /// Greedy shortest-column packing. Each item contributes `1 / ratio` to
    /// its column's running height (narrower ratio = taller cell), so the
    /// columns end up roughly balanced regardless of input order.
    private func distribute(_ items: [Item], into count: Int) -> [[Item]] {
        var cols: [[Item]] = Array(repeating: [], count: count)
        var heights: [Double] = Array(repeating: 0, count: count)

        for item in items {
            let shortestIndex = heights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            cols[shortestIndex].append(item)
            let ratio = aspectRatio(item)
            heights[shortestIndex] += ratio > 0 ? 1 / ratio : 1
        }
        return cols
    }
}

private struct GridWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
