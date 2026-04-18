import SwiftUI
import CoreText

struct ScanTransitionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var transition = ScanTransitionViewModel()
    @State private var scanVM = ScanViewModel()
    @Bindable var homeVM: HomeViewModel
    var heroNamespace: Namespace.ID?
    @Namespace private var localNamespace

    private var isScanning: Bool { transition.isScanning }
    private var contentEntered: Bool { transition.contentEntered }

    private var iconNamespace: Namespace.ID {
        heroNamespace ?? localNamespace
    }

    var body: some View {
        GeometryReader { bodyGeo in
            // Shared left inset: align home buttons under the "S" of SCAN.
            // Computed once from screen width so both morphingText and homeButtons agree.
            let scanLeftInset = scanLeftOffset(screenWidth: bodyGeo.size.width)

            VStack(alignment: .leading, spacing: 0) {
                // AppIcon — hero target from splash, skips draw animation
                AppIconDrawAnimation(skipDrawAnimation: heroNamespace != nil)
                    .frame(width: 160, height: 160)
                    .matchedGeometryEffect(id: "appIcon", in: iconNamespace)
                    .padding(.top, 40)
                    .padding(.horizontal, Self.horizontalInset)
                    .opacity(transition.appIconVisible ? 1 : 0)
                    .scaleEffect(transition.appIconVisible ? 1 : 0.6)
                    .animation(nil, value: isScanning)

                // Animated spacer — large in home, small in scan
                Spacer()
                    .frame(maxHeight: isScanning ? 24 : .infinity)

                // Morphing text (SCAN / SCANNING)
                morphingText

                // Home buttons — align under SCAN's "S" in home state; collapse in scan state
                homeButtons
                    .padding(.top, 16)
                    .padding(.leading, isScanning ? Self.horizontalInset : scanLeftInset)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: isScanning ? 0 : nil)
                    .clipped()

                // Scan content — elements stagger in after SCANNING positions
                scanContent
                    .frame(height: isScanning ? nil : 0)
                    .clipped()
                    .padding(.horizontal, Self.horizontalInset)

                Spacer()
                Spacer()
                    .frame(maxHeight: isScanning ? 0 : .infinity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .geometryGroup()
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isScanning)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    scanVM = ScanViewModel()
                    if reduceMotion { transition.jumpToHomeState() }
                    else { transition.animateToHome() }
                } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.semibold)
                }
                .opacity(isScanning ? 1 : 0)
                .disabled(!isScanning)
                .accessibilityLabel("Go back")
                .accessibilityHidden(!isScanning)
            }
        }
        .task {
            guard !contentEntered else { return }
            try? await Task.sleep(for: .milliseconds(600))
            if reduceMotion { transition.jumpToEnteredState() }
            else { transition.animateEntrance() }
        }
        .onChange(of: scanVM.scanCompleted) { _, completed in
            guard completed else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                if reduceMotion {
                    transition.jumpToHomeState()
                    homeVM.navigateToResults()
                } else {
                    transition.animateToResults {
                        homeVM.navigateToResults()
                    }
                }
            }
        }
    }

    // MARK: - Morphing Text

    private var morphingText: some View {
        GeometryReader { geo in
            // Design intent:
            //   • N flush with the right edge of the screen (trailing alignment).
            //   • S starts at minimum 20% from the left edge — i.e., SCAN's visual
            //     width is at most 80% of the screen.
            //   • On larger screens the font stays at the preferred size (doesn't grow);
            //     on narrow screens it shrinks so the 20% left margin is preserved.
            let screenWidth = max(1, geo.size.width)
            let maxScanWidth = screenWidth * (1 - Self.minLeftMarginRatio)

            // Pick fontSize: capped at preferred, reduced if preferred would exceed maxScanWidth.
            let scanWidthAtPreferred = measureText("SCAN", size: Self.preferredFontSize)
            let widthFitSize = (maxScanWidth / scanWidthAtPreferred) * Self.preferredFontSize
            let baseFontSize = min(Self.preferredFontSize, widthFitSize)

            // scan-state small size is fixed at 40pt; derive a dynamic targetScale from baseFontSize.
            let scanStateFontSize: CGFloat = 40
            let dynamicTargetScale = scanStateFontSize / baseFontSize

            // Remap VM's textScale (1.0 at home → targetScale=40/120 at scan) into
            // progress 0→1, then re-apply against the dynamic targetScale.
            let vmRange = 1.0 - ScanTransitionViewModel.targetScale
            let progress = vmRange > 0 ? (1.0 - transition.textScale) / vmRange : 0
            let scale = 1.0 + (dynamicTargetScale - 1.0) * progress

            let scanWidth = measureText("SCAN", size: baseFontSize)
            let scanningWidth = measureText("SCANNING", size: baseFontSize)
            let clipWidth = scanWidth + (scanningWidth - scanWidth) * transition.textRevealProgress

            return Button {
                guard !isScanning else { return }
                if reduceMotion { transition.jumpToScanState() }
                else { transition.animateToScan() }
                scanVM.startMockScan()
            } label: {
                Text("SCANNING")
                    .font(Font(Self.jostBlackUIFont(size: baseFontSize)))
                    .tracking(-4 * (baseFontSize / Self.referenceFontSize))
                    .foregroundStyle(foreground)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(width: clipWidth, alignment: .leading)
                    .clipped()
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(
                        width: clipWidth * scale,
                        height: baseFontSize * scale * 1.2, // 1.2 ≈ Jost-Black line height
                        alignment: .topLeading
                    )
            }
            .buttonStyle(.plain)
            .disabled(isScanning)
            .accessibilityLabel(isScanning ? "Scanning" : "Start scan")
            .opacity(transition.scanningTextVisible ? 1 : 0)
            .offset(x: contentEntered || isScanning ? 0 : offScreenOffset)
            .frame(maxWidth: .infinity, alignment: isScanning ? .leading : .trailing)
            .padding(.leading, isScanning ? Self.horizontalInset : 0)
            // Optical correction: pull the trailing edge slightly past the screen edge so
            // Jost-Black's right-side bearing doesn't leave a visible gap after the N.
            .padding(.trailing, isScanning ? 0 : -Self.trailingOpticalBleed)
        }
        .frame(height: Self.morphingTextContainerHeight)
    }

    // MARK: - Home Buttons

    private var homeButtons: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                homeVM.navigateToResults()
            } label: {
                Text("View Last Results")
                    .font(AppFont.subheadline)
                    .foregroundStyle(AppPalette.secondaryText)
            }
            .accessibilityLabel("View last scan results")
            .offset(x: transition.viewResultsVisible ? 0 : offScreenOffset)

            Toggle(isOn: $homeVM.forceRescan) {
                Text("Force Re-Scan")
                    .font(AppFont.subheadline)
            }
            .toggleStyle(CheckboxToggleStyle())
            .offset(x: transition.forceRescanVisible ? 0 : offScreenOffset)
        }
    }

    // MARK: - Scan Content

    private var scanContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. Photos count
            Text("\(scanVM.totalPhotos.formatted()) Photos")
                .font(AppFont.body)
                .padding(.top, 2)
                .opacity(transition.photosTextVisible ? 1 : 0)
                .offset(y: transition.photosTextVisible ? 0 : 12)

            // 2. Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.12))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(foreground)
                        .frame(width: geo.size.width * scanVM.progress, height: 8)
                        .animation(.linear(duration: 0.1), value: scanVM.progress)
                }
            }
            .frame(height: 8)
            .padding(.top, 12)
            .opacity(transition.progressBarVisible ? 1 : 0)
            .offset(y: transition.progressBarVisible ? 0 : 12)

            // 3. Scanned count
            HStack(spacing: 6) {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                Text("\(scanVM.scannedCount.formatted()) Scanned")
                    .font(AppFont.body)
            }
            .padding(.top, 12)
            .opacity(transition.scannedTextVisible ? 1 : 0)
            .offset(y: transition.scannedTextVisible ? 0 : 12)

            // 4-6. Report rows (stagger individually)
            VStack(spacing: 0) {
                ScanResultRow(text: scanVM.duplicatesText, shade: 0.08)
                    .opacity(transition.duplicatesRowVisible ? 1 : 0)
                    .offset(y: transition.duplicatesRowVisible ? 0 : 12)

                ScanResultRow(text: scanVM.screenshotsText, shade: 0.13)
                    .opacity(transition.screenshotsRowVisible ? 1 : 0)
                    .offset(y: transition.screenshotsRowVisible ? 0 : 12)

                ScanResultRow(text: scanVM.blankPhotosText, shade: 0.18)
                    .opacity(transition.blankPhotosRowVisible ? 1 : 0)
                    .offset(y: transition.blankPhotosRowVisible ? 0 : 12)
            }
            .padding(.top, 24)
        }
    }

    // MARK: - Helpers

    // Reference size we measure against to derive ratios. Any size works mathematically;
    // 120 keeps diffs readable vs the old code.
    private static let referenceFontSize: CGFloat = 120

    // Fixed preferred size for SCAN in the home state. Does NOT grow on larger screens —
    // only shrinks if it would violate the left-margin rule on narrow ones.
    private static let preferredFontSize: CGFloat = 140

    // S must start no closer than 20% from the left edge of the screen.
    private static let minLeftMarginRatio: CGFloat = 0.20

    // Outer frame height sized to Jost-Black's cap-height + ascender (~0.82 of font size).
    // Using the full 1.2× line-height reserves space for descenders SCAN/SCANNING don't have,
    // creating a visible gap below the text. 0.82 puts the frame bottom right at the visual
    // baseline so the next sibling's top-padding becomes the real vertical gap.
    private static let morphingTextContainerHeight: CGFloat = preferredFontSize * 1.05

    // Shared horizontal inset for scan-state text, AppIcon, and scan content.
    private static let horizontalInset: CGFloat = 24

    // Optical correction: how far past the screen edge to push the trailing edge
    // of the morphing text so the N glyph's right-side bearing doesn't leave a gap.
    // Set to 0 on real-device builds because device font metrics already push N right
    // to the edge; any positive bleed clips the glyph visibly.
    private static let trailingOpticalBleed: CGFloat = 0

    /// Left offset where "S" of SCAN sits in the home state (trailing-aligned, fixed size).
    /// Used to align home buttons directly under SCAN's leading edge.
    private func scanLeftOffset(screenWidth: CGFloat) -> CGFloat {
        let maxScanWidth = screenWidth * (1 - Self.minLeftMarginRatio)
        let scanWidthAtPreferred = measureText("SCAN", size: Self.preferredFontSize)
        let widthFitSize = (maxScanWidth / scanWidthAtPreferred) * Self.preferredFontSize
        let baseFontSize = min(Self.preferredFontSize, widthFitSize)
        let scanWidth = measureText("SCAN", size: baseFontSize)
        // Match the optical bleed applied to morphingText so buttons align with the
        // visual left edge of the S, not the theoretical frame edge.
        return max(Self.horizontalInset, screenWidth - scanWidth + Self.trailingOpticalBleed)
    }

    /// Offset to push trailing-aligned content just past the right viewport edge.
    /// Based on measured text width (the widest content), not hardcoded pixels.
    private var offScreenOffset: CGFloat {
        measureText("SCANNING") + 50
    }

    private var foreground: Color { colorScheme == .dark ? .white : .black }
    private var background: Color { colorScheme == .dark ? .black : .white }

    /// Width of `string` rendered in Jost-Black at `size` pt, with the -4 pt tracking
    /// applied manually (UIFont does not expose tracking, so we adjust afterward).
    /// Uses the variable-font CoreText loader so measurement matches what SwiftUI
    /// actually renders — `UIFont(name: "Jost-Black", ...)` fails strict PostScript-name
    /// lookup on some devices and silently falls back to a narrower system font,
    /// which makes the rendered text wider than predicted and clips at the screen edge.
    private func measureText(_ string: String, size: CGFloat = ScanTransitionView.referenceFontSize) -> CGFloat {
        let font = Self.jostBlackUIFont(size: size)
        let rawWidth = (string as NSString).size(withAttributes: [.font: font]).width
        // tracking(-4) in SwiftUI at 120pt removes ~4pt per character gap. Scale linearly with size.
        let trackingAdjustment = -4 * CGFloat(max(0, string.count - 1)) * (size / ScanTransitionView.referenceFontSize)
        return rawWidth + trackingAdjustment
    }

    // Variable-font CoreText loader for Jost-Black (weight 900).
    // Shared between the SwiftUI render path and the UIFont measurement path so they
    // cannot disagree on glyph widths.
    private static let variableCGFont: CGFont? = {
        guard let url = Bundle.main.url(forResource: "Jost-VariableFont_wght", withExtension: "ttf"),
              let provider = CGDataProvider(url: url as CFURL),
              let cgFont = CGFont(provider) else {
            return nil
        }
        return cgFont
    }()

    private static let weightAxisTag: UInt32 = 0x77676874  // 'wght'

    static func jostBlackUIFont(size: CGFloat) -> UIFont {
        guard let cgFont = variableCGFont else {
            return .systemFont(ofSize: size, weight: .black)
        }
        let ctFont = CTFontCreateWithGraphicsFont(cgFont, size, nil, nil)
        let variation = CTFontDescriptorCreateWithAttributes([
            kCTFontVariationAttribute: [weightAxisTag: 900 as CGFloat] as CFDictionary,
        ] as CFDictionary)
        let varied = CTFontCreateCopyWithAttributes(ctFont, size, nil, variation)
        return varied as UIFont
    }
}
