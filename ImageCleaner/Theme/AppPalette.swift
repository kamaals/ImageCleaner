import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Project-wide color palette tuned for WCAG AA contrast against the app's
/// standard surfaces (white in light mode, near-black in dark mode).
///
/// Prefer these over the semantic `.secondary` / `.tertiary` foreground styles
/// when contrast on small text matters — iOS's defaults sit at ~4.2:1 on white,
/// which is below AA for body text.
enum AppPalette {
    /// Secondary/metadata text. ~5.5:1 on white, ~8:1 on near-black.
    static let secondaryText = Color(
        light: Color(red: 0.32, green: 0.32, blue: 0.32),
        dark: Color(red: 0.78, green: 0.78, blue: 0.78)
    )
}

extension Color {
    /// Returns a dynamic color that resolves to `light` in light mode and `dark` in dark mode.
    init(light: Color, dark: Color) {
        self.init(
            UIColor { trait in
                trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
            }
        )
    }
}
