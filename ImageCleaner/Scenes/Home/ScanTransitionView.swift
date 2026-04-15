import SwiftUI

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
        VStack(alignment: .leading, spacing: 0) {
            // AppIcon — hero target from splash, skips draw animation
            AppIconView(
                foreground: foreground,
                invertedForeground: background,
                skipDrawAnimation: heroNamespace != nil
            )
            .frame(width: 100, height: 100)
            .matchedGeometryEffect(id: "appIcon", in: iconNamespace)
            .padding(.top, 40)
            .padding(.horizontal, 24)
            .opacity(transition.appIconVisible ? 1 : 0)
            .scaleEffect(transition.appIconVisible ? 1 : 0.6)
            .animation(nil, value: isScanning)

            // Animated spacer — large in home, small in scan
            Spacer()
                .frame(maxHeight: isScanning ? 24 : .infinity)

            // Morphing text (SCAN / SCANNING)
            morphingText

            // Home buttons — independent of morphingText so they slide out freely
            homeButtons
                .padding(.top, 16)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 12)
                .frame(height: isScanning ? 0 : nil)

            // Scan content — elements stagger in after SCANNING positions
            scanContent
                .frame(height: isScanning ? nil : 0)
                .clipped()
                .padding(.horizontal, 24)

            Spacer()
            Spacer()
                .frame(maxHeight: isScanning ? 0 : .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            let sidePadding: CGFloat = 24
            let availableWidth = max(1, geo.size.width - sidePadding * 2)

            // baseFontSize: size at which "SCAN" exactly fills availableWidth.
            let scanWidthAtRef = measureText("SCAN", size: Self.referenceFontSize)
            let baseFontSize = (availableWidth / scanWidthAtRef) * Self.referenceFontSize

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
                    .font(.custom("Jost-Black", size: baseFontSize, relativeTo: .largeTitle))
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, sidePadding)
        }
        .frame(height: Self.referenceFontSize * 1.2)
    }

    // MARK: - Home Buttons

    private var homeButtons: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                homeVM.navigateToResults()
            } label: {
                Text("View Last Results")
                    .font(AppFont.subheadline)
                    .foregroundStyle(.secondary)
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
                        .fill(.secondary.opacity(0.2))
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

    /// Offset to push trailing-aligned content just past the right viewport edge.
    /// Based on measured text width (the widest content), not hardcoded pixels.
    private var offScreenOffset: CGFloat {
        measureText("SCANNING") + 50
    }

    private var foreground: Color { colorScheme == .dark ? .white : .black }
    private var background: Color { colorScheme == .dark ? .black : .white }

    /// Width of `string` rendered in Jost-Black at `size` pt, with the -4 pt tracking
    /// applied manually (UIFont does not expose tracking, so we adjust afterward).
    private func measureText(_ string: String, size: CGFloat = ScanTransitionView.referenceFontSize) -> CGFloat {
        let font = UIFont(name: "Jost-Black", size: size) ?? .systemFont(ofSize: size, weight: .black)
        let rawWidth = (string as NSString).size(withAttributes: [.font: font]).width
        // tracking(-4) in SwiftUI at 120pt removes ~4pt per character gap. Scale linearly with size.
        let trackingAdjustment = -4 * CGFloat(max(0, string.count - 1)) * (size / ScanTransitionView.referenceFontSize)
        return rawWidth + trackingAdjustment
    }
}
