import SwiftUI

struct ResultsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ScanStore.self) private var store

    private var foreground: Color { colorScheme == .dark ? .white : .black }
    private var background: Color { colorScheme == .dark ? .black : .white }

    private var totalItemsFound: Int {
        guard let session = store.latestSession else { return 0 }
        return session.duplicateGroupCount + session.screenshotCount + session.blankCount
    }

    private var reclaimableText: String {
        let bytes = store.latestSession?.reclaimableBytes ?? 0
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private var duplicateGroupCount: Int { store.latestSession?.duplicateGroupCount ?? 0 }
    private var screenshotCount: Int { store.latestSession?.screenshotCount ?? 0 }
    private var blankCount: Int { store.latestSession?.blankCount ?? 0 }

    private var duplicateBytes: Int64 {
        store.duplicates.reduce(0) { running, group in
            let members = group.images
            let largest = members.max(by: { $0.fileSize < $1.fileSize })?.fileSize ?? 0
            let sum = members.reduce(0) { $0 + $1.fileSize }
            return running + (sum - largest)
        }
    }

    private var screenshotBytes: Int64 {
        store.screenshots.reduce(0) { $0 + $1.fileSize }
    }

    private var blankBytes: Int64 {
        store.blanks.reduce(0) { $0 + $1.fileSize }
    }

    private func formatted(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    // Animation state - row visibility
    @State private var headerVisible = false
    @State private var valueVisible = false
    @State private var duplicatesVisible = false
    @State private var screenshotsVisible = false
    @State private var blankPhotosVisible = false

    // Animation state - icon IDs (changing ID forces view recreation and re-triggers onAppear)
    @State private var headerIconID = UUID()
    @State private var duplicatesIconID = UUID()
    @State private var screenshotsIconID = UUID()
    @State private var blankPhotosIconID = UUID()
    
    // Track if icons should animate (false = skip, true = animate)
    @State private var headerIconReady = false
    @State private var duplicatesIconReady = false
    @State private var screenshotsIconReady = false
    @State private var blankPhotosIconReady = false

    private let offScreenX: CGFloat = -60
    private let offScreenY: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Reclaimable Space header
            HStack(alignment: .center, spacing: 4) {
                ResizeIcon(
                    foreground: foreground,
                    invertedForeground: background,
                    skipAnimation: !headerIconReady
                )
                .id(headerIconID)
                .frame(width: 64, height: 64)
                .opacity(headerIconReady ? 1 : 0)

                VStack(alignment: .leading, spacing: -2) {
                    Text("RECLAIMABLE SPACE")
                        .font(AppFont.jost(size: 28, weight: 500))
                        .foregroundStyle(foreground)
                        .fixedSize()

                    Text("\(totalItemsFound) items found")
                        .font(AppFont.jost(size: 16, weight: 400))
                        .foregroundStyle(AppPalette.secondaryText)
                        .fixedSize()
                }
            }
            .geometryGroup()
            .padding(.top, 24)
            .opacity(headerVisible ? 1 : 0)
            .offset(x: headerVisible ? 0 : offScreenX)

            // Reclaimable Space value
            HStack {
                Spacer().frame(maxWidth: 4)
                Text(reclaimableText)
                    .font(AppFont.jost(size: 48, weight: 200))
                    .foregroundStyle(foreground)
                    .fixedSize()
            }
            .geometryGroup()
            .opacity(valueVisible ? 1 : 0)
            .offset(x: valueVisible ? 0 : offScreenX)

            // Category list
            VStack(spacing: 24) {
                NavigationLink(value: HomeDestination.duplicates) {
                    ResultCategoryRow(
                        icon: DuplicateIcon(
                            foreground: foreground,
                            invertedForeground: background,
                            skipAnimation: !duplicatesIconReady
                        )
                        .id(duplicatesIconID)
                        .opacity(duplicatesIconReady ? 1 : 0),
                        title: "Duplicate Photos",
                        itemCount: duplicateGroupCount,
                        size: formatted(duplicateBytes),
                        foreground: foreground
                    )
                }
                .opacity(duplicatesVisible ? 1 : 0)
                .offset(y: duplicatesVisible ? 0 : offScreenY)

                NavigationLink(value: HomeDestination.screenshots) {
                    ResultCategoryRow(
                        icon: ScanLinesIcon(
                            foreground: foreground,
                            invertedForeground: background,
                            skipAnimation: !screenshotsIconReady
                        )
                        .id(screenshotsIconID)
                        .opacity(screenshotsIconReady ? 1 : 0),
                        title: "Screenshots",
                        itemCount: screenshotCount,
                        size: formatted(screenshotBytes),
                        foreground: foreground
                    )
                }
                .opacity(screenshotsVisible ? 1 : 0)
                .offset(y: screenshotsVisible ? 0 : offScreenY)

                NavigationLink(value: HomeDestination.blankPhotos) {
                    ResultCategoryRow(
                        icon: LayersIcon(
                            foreground: foreground,
                            invertedForeground: background,
                            skipAnimation: !blankPhotosIconReady
                        )
                        .id(blankPhotosIconID)
                        .opacity(blankPhotosIconReady ? 1 : 0),
                        title: "Blank Photos",
                        itemCount: blankCount,
                        size: formatted(blankBytes),
                        foreground: foreground
                    )
                }
                .opacity(blankPhotosVisible ? 1 : 0)
                .offset(y: blankPhotosVisible ? 0 : offScreenY)
            }
            .padding(.top, 32)

            Spacer()
        }
        .padding(.horizontal, AppLayout.horizontalInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationBarTitleDisplayMode(.inline)
        .arrowBackButton()
        .onAppear {
            if reduceMotion {
                jumpToVisible()
            } else {
                animateEntrance()
            }
        }
    }

    // MARK: - Animation Methods

    private func jumpToVisible() {
        headerVisible = true
        valueVisible = true
        duplicatesVisible = true
        screenshotsVisible = true
        blankPhotosVisible = true
    }

    private func animateEntrance() {
        let spring = Animation.spring(response: 0.5, dampingFraction: 0.9)
        let staggerInterval: Double = 0.2

        // 1. Header slides in from left, then icon animates
        withAnimation(spring) {
            headerVisible = true
        } completion: {
            // Set ready flag and change ID to force icon recreation with animation enabled
            headerIconReady = true
            headerIconID = UUID()
        }

        // 2. Value slides in from left (after header)
        withAnimation(spring.delay(staggerInterval)) {
            valueVisible = true
        }

        // 3. Category rows stagger in from bottom, icons animate after settling
        withAnimation(spring.delay(staggerInterval * 2)) {
            duplicatesVisible = true
        } completion: {
            duplicatesIconReady = true
            duplicatesIconID = UUID()
        }
        
        withAnimation(spring.delay(staggerInterval * 3)) {
            screenshotsVisible = true
        } completion: {
            screenshotsIconReady = true
            screenshotsIconID = UUID()
        }
        
        withAnimation(spring.delay(staggerInterval * 4)) {
            blankPhotosVisible = true
        } completion: {
            blankPhotosIconReady = true
            blankPhotosIconID = UUID()
        }
    }

}

#Preview {
    NavigationStack {
        ResultsView()
            .environment(AppTheme())
    }
}
