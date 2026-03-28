import SwiftUI

struct ScanTransitionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var transition = ScanTransitionViewModel()
    @State private var scanVM = ScanViewModel()
    @Bindable private var homeVM: HomeViewModel

    init(homeVM: HomeViewModel) {
        self.homeVM = homeVM
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Shared AppIconView — pinned at top-left
            AppIconView(
                foreground: foreground,
                invertedForeground: background
            )
            .frame(
                width: transition.isScanning ? 120 : 100,
                height: transition.isScanning ? 120 : 100
            )
            .padding(.top, transition.isScanning ? 24 : 40)
            .padding(.leading, 24)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: transition.isScanning)

            // Content layer
            VStack(alignment: .leading, spacing: 0) {
                // Spacer for icon height
                Color.clear.frame(height: transition.isScanning ? 168 : 0)

                if !transition.isScanning {
                    Spacer()
                } else {
                    Spacer().frame(height: 24)
                }

                // Morphing text: "SCAN" ↔ "SCANNING"
                morphingText

                // Home-only content (fades out)
                if transition.homeContentOpacity > 0 {
                    homeButtons
                        .opacity(transition.homeContentOpacity)
                }

                // Scan-only content (fades in)
                if transition.scanContentOpacity > 0 {
                    scanContent
                        .opacity(transition.scanContentOpacity)
                }

                Spacer()
                if !transition.isScanning { Spacer() }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Morphing Text

    private var morphingText: some View {
        let scanWidth = measureText("SCAN")
        let scanningWidth = measureText("SCANNING")
        let currentWidth = scanWidth + (scanningWidth - scanWidth) * transition.textRevealProgress

        return Button {
            if transition.isScanning {
                scanVM = ScanViewModel()
                if reduceMotion { transition.jumpToHomeState() }
                else { transition.animateToHome() }
            } else {
                if reduceMotion {
                    transition.jumpToScanState()
                } else {
                    transition.animateToScan()
                }
                scanVM.startMockScan()
            }
        } label: {
            Text("SCANNING")
                .font(.custom("Jost-Black", size: 120, relativeTo: .largeTitle))
                .tracking(-4)
                .foregroundStyle(foreground)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: currentWidth, alignment: .leading)
                .clipped()
        }
        .scaleEffect(transition.textScale, anchor: .topLeading)
        .padding(.bottom, transition.isScanning ? 0 : -40)
        .frame(maxWidth: .infinity, alignment: transition.isScanning ? .leading : .trailing)
        .padding(.leading, transition.isScanning ? 24 : 0)
        .padding(.trailing, transition.isScanning ? 0 : -12)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: transition.isScanning)
        .accessibilityLabel(transition.isScanning ? "Scanning in progress" : "Start scan")
    }

    // MARK: - Home Buttons

    private var homeButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                homeVM.navigateToResults()
            } label: {
                Text("View Last Results")
                    .font(AppFont.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("View last scan results")

            Toggle(isOn: $homeVM.forceRescan) {
                Text("Force Re-Scan")
                    .font(AppFont.subheadline)
            }
            .toggleStyle(CheckboxToggleStyle())
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, -12)
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
                        .fill(Color(.systemGray4))
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
        .padding(.horizontal, 24)
    }

    // MARK: - Helpers

    private var foreground: Color { colorScheme == .dark ? .white : .black }
    private var background: Color { colorScheme == .dark ? .black : .white }

    private func measureText(_ string: String) -> CGFloat {
        let font = UIFont(name: "Jost-Black", size: 120) ?? .systemFont(ofSize: 120, weight: .black)
        return (string as NSString).size(withAttributes: [.font: font]).width
    }
}
