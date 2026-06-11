import SwiftUI

struct SplashView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Optional so SwiftUI previews (which don't inject a ScanStore) still build;
    // resolves to the real store in the running app.
    @Environment(ScanStore.self) private var store: ScanStore?
    @Namespace private var heroNamespace
    @State private var isFinished = false
    @State private var showWordmark = false

    private let iconSize: CGFloat = 240

    /// Entry and exit share this animation — toggling `showWordmark` runs it
    /// both directions, so exit mirrors entry exactly.
    private let wordmarkAnimation: Animation = .easeOut(duration: 0.45)

    /// Hold the wordmark fully visible for this long before starting the exit.
    private let wordmarkHoldSeconds: Double = 1.0

    var body: some View {
        if isFinished {
            // Hand off to the home stack. The icon hero only runs when the
            // destination actually shows the SCAN icon — saved-results and
            // permission-gate launches hide or replace it, so passing the
            // namespace there would orphan the matchedGeometryEffect.
            ContentView(
                heroNamespace: launchHeroNamespace,
                startWithResults: hasSavedResults
            )
        } else {
            splash
        }
    }

    /// A previously completed scan is persisted in SwiftData, so we can show
    /// the last results immediately without re-scanning.
    private var hasSavedResults: Bool {
        store?.latestSession?.isComplete == true
    }

    /// `true` when the home will render the full-screen permission state instead
    /// of the SCAN icon (denied / limited / restricted). `.needsPriming` and
    /// `.granted` are excluded — they show the normal SCAN home.
    private var showsPermissionGate: Bool {
        switch store?.photoAccess {
        case .denied, .needsFullAccess, .restricted: true
        default: false
        }
    }

    /// The icon hero runs only for a normal SCAN-home handoff.
    private var launchHeroNamespace: Namespace.ID? {
        (hasSavedResults || showsPermissionGate) ? nil : heroNamespace
    }

    private var splash: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            ZStack(alignment: .topLeading) {
                AppIconDrawAnimation(onFinished: runWordmarkSequence)
                    .frame(width: iconSize, height: iconSize)
                    .matchedGeometryEffect(id: "appIcon", in: heroNamespace)

                VStack(alignment: .leading, spacing: -iconSize * 0.040) {
                    Text("Photo")
                    Text("Prune")
                }
                .font(AppFont.jost(size: iconSize * 0.08, weight: 400))
                .foregroundStyle(foregroundColor)
                .padding(.leading, iconSize * 0.23)
                .padding(.top, iconSize * 0.55)
                .opacity(showWordmark ? 1 : 0)
                .offset(y: showWordmark ? 0 : 6)
                .accessibilityLabel("PhotoPrune")
            }
            .frame(width: iconSize, height: iconSize)
        }
    }

    /// Fires after `AppIconDrawAnimation` completes its draw-in. Reveals the
    /// wordmark, holds, exits it with the same animation (reverse direction),
    /// then hands off to `ContentView` via the `matchedGeometryEffect` hero.
    private func runWordmarkSequence() {
        Task { @MainActor in
            // Entry
            withAnimation(wordmarkAnimation) { showWordmark = true }
            try? await Task.sleep(for: .seconds(0.45 + wordmarkHoldSeconds))

            // Exit — same animation, direction reverses via showWordmark flip
            withAnimation(wordmarkAnimation) { showWordmark = false }
            try? await Task.sleep(for: .milliseconds(450))

            // Now hand off to ContentView
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
                isFinished = true
            }
        }
    }

    private var foregroundColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? .black : .white
    }
}

#Preview("Light") {
    SplashView()
        .environment(AppTheme())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    SplashView()
        .environment(AppTheme())
        .preferredColorScheme(.dark)
}
