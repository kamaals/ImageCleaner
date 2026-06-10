import SwiftUI

/// Full-screen Photos-permission state shown in place of the SCAN home when the
/// app can't scan: priming before the first request, or a recovery prompt when
/// access is denied / limited / restricted.
///
/// Matches the splash + paywall brand: monochrome ink/paper that inverts with
/// the color scheme, Jost display type, the stair-step app mark, and the
/// signature offset-shadow button (see `PaywallView.ctaSection`). The brand is
/// hard-edged — no corner radii.
struct PhotoAccessView: View {
    @Environment(\.colorScheme) private var colorScheme

    let state: PhotoAccessState
    /// Invoked by the primary button. For `.needsPriming` the caller triggers
    /// the system permission request; for the recovery states it deep-links to
    /// Settings.
    let onPrimaryAction: () -> Void

    private var ink: Color { colorScheme == .dark ? .white : .black }
    private var paper: Color { colorScheme == .dark ? .black : .white }

    var body: some View {
        ZStack {
            paper.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)

                AppIconView(
                    foreground: ink,
                    invertedForeground: paper,
                    skipDrawAnimation: true
                )
                .frame(width: 112, height: 112)
                .accessibilityHidden(true)
                .padding(.bottom, 40)

                Text("PHOTO ACCESS")
                    .font(AppFont.jost(size: 16, relativeTo: .callout, weight: 500))
                    .tracking(1.5)
                    .foregroundStyle(AppPalette.secondaryText)
                    .padding(.bottom, 8)

                Text(headline)
                    .font(AppFont.jost(size: 48, weight: 900))
                    .foregroundStyle(ink)
                    .lineSpacing(-4)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.7)
                    .padding(.bottom, 20)

                Text(message)
                    .font(AppFont.jost(size: 17, relativeTo: .body, weight: 400))
                    .foregroundStyle(ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 36)

                primaryButton

                Spacer(minLength: 0)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppLayout.horizontalInset)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Signature offset-shadow CTA (mirrors PaywallView.ctaSection)

    private var primaryButton: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(ink)
                .frame(height: 54)
                .offset(x: 6, y: 8)

            Button(action: onPrimaryAction) {
                ZStack {
                    Rectangle()
                        .fill(paper)
                        .overlay(Rectangle().stroke(ink, lineWidth: 0.5))
                    Text(buttonTitle)
                        .font(AppFont.jost(size: 16, relativeTo: .callout, weight: 500))
                        .tracking(2)
                        .foregroundStyle(ink)
                }
                .frame(height: 54)
            }
            .buttonStyle(.plain)
        }
        .padding(.trailing, 6)
        .accessibilityLabel(buttonTitle)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - State copy

    private var headline: String {
        switch state {
        case .needsPriming, .denied, .needsFullAccess: "FULL\nACCESS\nNEEDED"
        case .restricted: "ACCESS\nRESTRICTED"
        case .granted: "FULL\nACCESS\nNEEDED" // unused: granted never renders this view
        }
    }

    private var message: String {
        switch state {
        case .needsPriming:
            "PhotoPrune scans your whole library to find duplicates, screenshots, and blank photos so you can reclaim storage. Your photos never leave your device."
        case .denied:
            "PhotoPrune doesn't have access to your photos. Open Settings and turn on Photos → All Photos to start cleaning up your library."
        case .needsFullAccess:
            "PhotoPrune has limited access — it can only see the photos you picked. To scan your whole library, open Settings and choose All Photos."
        case .restricted:
            "Photo access is restricted on this device, likely by Screen Time or a device-management profile. That restriction has to be lifted before PhotoPrune can scan."
        case .granted:
            ""
        }
    }

    private var buttonTitle: String {
        switch state {
        case .needsPriming: "ALLOW ACCESS"
        case .denied, .needsFullAccess, .restricted: "OPEN SETTINGS"
        case .granted: ""
        }
    }
}

#Preview("Priming — Light") {
    PhotoAccessView(state: .needsPriming, onPrimaryAction: {})
        .preferredColorScheme(.light)
}

#Preview("Denied — Dark") {
    PhotoAccessView(state: .denied, onPrimaryAction: {})
        .preferredColorScheme(.dark)
}

#Preview("Limited — Light") {
    PhotoAccessView(state: .needsFullAccess, onPrimaryAction: {})
        .preferredColorScheme(.light)
}

#Preview("Restricted — Dark") {
    PhotoAccessView(state: .restricted, onPrimaryAction: {})
        .preferredColorScheme(.dark)
}
