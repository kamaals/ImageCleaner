import SwiftUI

/// Animated icon — two overlapping outlined squares. The front square
/// has a white fill at 80% opacity, partially revealing the back square's border.
/// Scales to any frame size. Use like: `LayersIcon().frame(width: 60, height: 60)`
struct LayersIcon: View {
    var foreground: Color = .primary
    var invertedForeground: Color = .white
    var skipAnimation = false

    @State private var backTrim: CGFloat = 0
    @State private var frontTrim: CGFloat = 0
    @State private var offsetProgress: CGFloat = 0
    @State private var frontFillOpacity: Double = 0
    @State private var hasAppeared = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let designSize: CGFloat = 200

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)

            iconLayers(for: size)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Layers icon")
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            if skipAnimation || reduceMotion { jumpToCompleted() }
            else { startAnimation() }
        }
        .onChange(of: skipAnimation) { oldValue, newValue in
            // Trigger animation when skipAnimation changes from true to false
            if oldValue == true && newValue == false && !reduceMotion {
                startAnimation()
            }
        }
    }

    private func iconLayers(for size: CGFloat) -> some View {
        let s = size / Self.designSize

        let squareSide: CGFloat = 140 * s
        let maxOffset: CGFloat  = 22 * s
        let borderW: CGFloat    = max(3.5 * s, 1.0)
        let currentOffset       = offsetProgress * maxOffset

        return ZStack {
            Rectangle()
                .trim(from: 0, to: backTrim)
                .stroke(foreground, style: StrokeStyle(lineWidth: borderW, lineCap: .square, lineJoin: .miter))
                .frame(width: squareSide, height: squareSide)
                .offset(x: -currentOffset, y: currentOffset)

            Rectangle()
                .fill(invertedForeground.opacity(0.8))
                .frame(width: squareSide, height: squareSide)
                .offset(x: currentOffset, y: -currentOffset)
                .opacity(frontFillOpacity)

            Rectangle()
                .trim(from: 0, to: frontTrim)
                .stroke(foreground, style: StrokeStyle(lineWidth: borderW, lineCap: .square, lineJoin: .miter))
                .frame(width: squareSide, height: squareSide)
                .offset(x: currentOffset, y: -currentOffset)
        }
        .frame(width: size, height: size)
    }

    private func jumpToCompleted() {
        backTrim = 1.0
        frontTrim = 1.0
        offsetProgress = 1.0
        frontFillOpacity = 1.0
    }

    private func startAnimation() {
        withAnimation(.easeInOut(duration: 1.0)) { backTrim = 1.0 }
        withAnimation(.easeInOut(duration: 1.0).delay(0.6)) { frontTrim = 1.0 }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(1.4)) { offsetProgress = 1.0 }
        withAnimation(.easeIn(duration: 0.5).delay(2.0)) { frontFillOpacity = 1.0 }
    }
}
