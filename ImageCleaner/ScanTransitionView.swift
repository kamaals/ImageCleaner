import SwiftUI

struct ScanTransitionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var transition = ScanTransitionViewModel()
    @State private var scanVM = ScanViewModel()
    @Bindable var homeVM: HomeViewModel

    private var isScanning: Bool { transition.isScanning }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Shared AppIconView — transaction strips all animation (explicit + implicit)
            AppIconView(
                foreground: foreground,
                invertedForeground: background
            )
            .frame(width: 100, height: 100)
            .padding(.top, 40)
            .padding(.horizontal, 24)
            .transaction { $0.animation = nil }

            // Animated spacer — large in home, small in scan
            Spacer()
                .frame(maxHeight: isScanning ? 24 : .infinity)

            // Morphing text — single view, no if/else branching
            morphingText

            // Home buttons — fade out
            homeButtons
                .frame(height: isScanning ? 0 : nil)
                .opacity(transition.homeContentOpacity)
                .clipped()

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
        .padding(.bottom, isScanning ? 0 : -20)
        .frame(maxWidth: .infinity, alignment: isScanning ? .leading : .trailing)
        .padding(.leading, isScanning ? 24 : 0)
        .padding(.trailing, isScanning ? 0 : -12)
        .accessibilityLabel(isScanning ? "Scanning" : "Start scan")
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
    }

    // MARK: - Helpers

    private var foreground: Color { colorScheme == .dark ? .white : .black }
    private var background: Color { colorScheme == .dark ? .black : .white }

    private func measureText(_ string: String) -> CGFloat {
        let font = UIFont(name: "Jost-Black", size: 120) ?? .systemFont(ofSize: 120, weight: .black)
        return (string as NSString).size(withAttributes: [.font: font]).width
    }
}
