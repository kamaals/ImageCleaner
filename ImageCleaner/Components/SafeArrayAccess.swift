import Foundation

extension Collection {
    /// Safe subscript — returns `nil` for out-of-bounds indexes instead of
    /// crashing. Used by the grid view models' `binding(for:)` helpers when
    /// an index is temporarily stale between reloads.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
