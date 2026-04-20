import SwiftUI

/// Pinterest-style waterfall grid with lazy per-column rendering.
///
/// - Each item is pre-assigned to the shortest column based on its aspect
///   ratio (items with smaller aspect ratio — taller cells — contribute more
///   to a column's accumulated height).
/// - Columns are rendered as parallel `LazyVStack`s inside an `HStack`. Only
///   the cells currently visible in the enclosing `ScrollView` are
///   instantiated, so navigating into a view with thousands of items is
///   instant and thumbnail loads are triggered lazily.
///
/// Usage:
///
///     PinterestGrid(items: photos, columns: 3, spacing: 8, aspectRatio: { $0.aspectRatio }) { photo in
///         PhotoCell(photo: photo)
///     }
struct PinterestGrid<Item: Identifiable & Equatable, Cell: View>: View {
    let items: [Item]
    let columns: Int
    let spacing: CGFloat
    let aspectRatio: (Item) -> Double
    @ViewBuilder let cell: (Item) -> Cell

    init(
        items: [Item],
        columns: Int = 3,
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
        let assignments = distribute(items, into: columns)
        HStack(alignment: .top, spacing: spacing) {
            ForEach(0..<columns, id: \.self) { columnIndex in
                LazyVStack(spacing: spacing) {
                    ForEach(assignments[columnIndex]) { item in
                        cell(item)
                            .aspectRatio(aspectRatio(item), contentMode: .fit)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    /// Greedy shortest-column packing. Each item's height contribution is
    /// `1 / aspectRatio` — wider cells are shorter per column-unit, narrower
    /// cells taller — so columns end up roughly balanced.
    private func distribute(_ items: [Item], into count: Int) -> [[Item]] {
        var columns: [[Item]] = Array(repeating: [], count: count)
        var heights: [Double] = Array(repeating: 0, count: count)

        for item in items {
            let shortestIndex = heights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            columns[shortestIndex].append(item)
            let ratio = aspectRatio(item)
            heights[shortestIndex] += ratio > 0 ? 1 / ratio : 1
        }
        return columns
    }
}
