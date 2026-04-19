import SwiftUI

/// Replaces the default NavigationStack chevron back button with a plain
/// arrow (`arrow.left`). Apply to any pushed destination that wants the
/// arrow treatment — uses `@Environment(\.dismiss)` so the caller doesn't
/// need to wire up an action.
///
/// ```swift
/// var body: some View {
///     ContentView()
///         .arrowBackButton()          // always visible
///         .arrowBackButton(isHidden: isBusy)  // conditionally hidden
/// }
/// ```
struct ArrowBackButtonModifier: ViewModifier {
    let isHidden: Bool
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back", systemImage: "arrow.left") {
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                    .opacity(isHidden ? 0 : 1)
                    .disabled(isHidden)
                    .accessibilityHidden(isHidden)
                }
            }
    }
}

extension View {
    /// Replaces the system chevron back button with an `arrow.left` icon that
    /// dismisses the current destination. Pass `isHidden: true` to hide the
    /// arrow (and the system chevron) during transient states.
    func arrowBackButton(isHidden: Bool = false) -> some View {
        modifier(ArrowBackButtonModifier(isHidden: isHidden))
    }
}
