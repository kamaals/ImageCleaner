import SwiftUI

/// Press feedback for the duplicate-card delete badge. Disc, glyph, and ring
/// scale and dim together on touch-down, so a press registers as one crisp,
/// self-contained response — making "did I hit the ×?" unambiguous.
struct DeleteBadgeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.82 : 1)
            .opacity(configuration.isPressed ? 0.65 : 1)
            .animation(
                .spring(response: 0.2, dampingFraction: 0.6),
                value: configuration.isPressed
            )
    }
}
