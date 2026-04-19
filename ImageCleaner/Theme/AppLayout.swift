import CoreGraphics

/// Project-wide layout constants. Keep magic numbers out of individual views
/// so a single tweak updates every screen.
enum AppLayout {
    /// Shared horizontal inset applied to content on every screen. Matches the
    /// Scanning screen, which is the reference design for margin alignment.
    static let horizontalInset: CGFloat = 24
}
