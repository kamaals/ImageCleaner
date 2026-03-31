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
            .animation(nil, value: isScanning)

            // Animated spacer — large in home, small in scan
            Spacer()
                .frame(maxHeight: isScanning ? 24 : .infinity)

            // Morphing text (SCAN / SCANNING)
            morphingText

            // Home buttons — independent of morphingText so they slide out freely
            homeButtons
                .padding(.top, 16)
                .frame(width: measureText("SCAN"), alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, -12)
                .frame(height: isScanning ? 0 : nil)

            // Scan content — fades in
            scanContent
                .frame(height: isScanning ? nil : 0)
                .opacity(transition.scanContentOpacity)
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
    }

    // MARK: - Morphing Text

    private var morphingText: some View {
        let scanWidth = measureText("SCAN")
        let scanningWidth = measureText("SCANNING")
        let clipWidth = scanWidth + (scanningWidth - scanWidth) * transition.textRevealProgress
        let scale = transition.textScale

        return Button {
            guard !isScanning else { return }
            if reduceMotion { transition.jumpToScanState() }
            else { transition.animateToScan() }
            scanVM.startMockScan()
        } label: {
            Text("SCANNING")
                .font(.custom("Jost-Black", size: 120, relativeTo: .largeTitle))
                .tracking(-4)
                .foregroundStyle(foreground)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: clipWidth, alignment: .leading)
                .clipped()
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: clipWidth * scale, height: 120 * scale, alignment: .topLeading)
        }
        .disabled(isScanning)
        .accessibilityLabel(isScanning ? "Scanning" : "Start scan")
        .offset(x: contentEntered || isScanning ? 0 : offScreenOffset)
        .frame(maxWidth: .infinity, alignment: isScanning ? .leading : .trailing)
        .padding(.leading, isScanning ? 24 : 0)
        .padding(.trailing, isScanning ? 0 : -12)
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
            Text("\(scanVM.totalPhotos.formatted()) Photos")
                .font(AppFont.body)
                .padding(.top, 2)

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

            HStack(spacing: 6) {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                Text("\(scanVM.scannedCount.formatted()) Scanned")
                    .font(AppFont.body)
            }
            .padding(.top, 12)

            VStack(spacing: 0) {
                ScanResultRow(text: scanVM.duplicatesText)
                ScanResultRow(text: scanVM.screenshotsText)
                ScanResultRow(text: scanVM.blankPhotosText)
            }
            .padding(.top, 24)
        }
    }

    // MARK: - Helpers

    /// Offset to push trailing-aligned content just past the right viewport edge.
    /// Based on measured text width (the widest content), not hardcoded pixels.
    private var offScreenOffset: CGFloat {
        measureText("SCANNING") + 50
    }

    private var foreground: Color { colorScheme == .dark ? .white : .black }
    private var background: Color { colorScheme == .dark ? .black : .white }

    private func measureText(_ string: String) -> CGFloat {
        let font = UIFont(name: "Jost-Black", size: 120) ?? .systemFont(ofSize: 120, weight: .black)
        return (string as NSString).size(withAttributes: [.font: font]).width
    }
}
