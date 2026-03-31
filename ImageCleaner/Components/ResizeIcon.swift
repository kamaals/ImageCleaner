import SwiftUI

/// Animated resize/crop icon — large square with L-shaped corner step and small square.
/// Scales to any frame size. Use like: `ResizeIcon().frame(width: 60, height: 60)`
struct ResizeIcon: View {
    var foreground: Color = .primary
    var invertedForeground: Color = .white
    var skipAnimation = false

    @State private var outlineTrim: CGFloat = 0
    @State private var outlineOpacity: Double = 1
    @State private var fillOpacity: Double = 0
    @State private var lCutTrim: CGFloat = 0
    @State private var notchReveal: Double = 0
    @State private var smallSquareScale: CGFloat = 0
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
        .accessibilityLabel("Resize icon")
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            if skipAnimation || reduceMotion {
                jumpToCompleted()
            } else {
                startAnimation()
            }
        }
    }

    // MARK: - Icon Composition

    private func iconLayers(for size: CGFloat) -> some View {
        let s = size / Self.designSize

        let bigSide: CGFloat    = 155 * s
        let smallSide: CGFloat  = 30 * s
        let gap: CGFloat        = 8 * s
        let notch: CGFloat      = smallSide + gap
        let strokeW: CGFloat    = max(2.5 * s, 0.75)
        let lStrokeW: CGFloat   = gap

        let bigX = (size - bigSide) / 2
        let bigY = (size - bigSide) / 2
        let bigCX = bigX + bigSide / 2
        let bigCY = bigY + bigSide / 2

        let smallCX = bigX + bigSide - smallSide / 2
        let smallCY = bigY + smallSide / 2

        let lStart  = CGPoint(x: bigX + bigSide - notch, y: bigY)
        let lCorner = CGPoint(x: bigX + bigSide - notch, y: bigY + notch)
        let lEnd    = CGPoint(x: bigX + bigSide,         y: bigY + notch)

        return ZStack {
            Rectangle()
                .fill(foreground)
                .frame(width: bigSide, height: bigSide)
                .position(x: bigCX, y: bigCY)
                .opacity(fillOpacity)

            Rectangle()
                .trim(from: 0, to: outlineTrim)
                .stroke(
                    foreground,
                    style: StrokeStyle(lineWidth: strokeW, lineCap: .square, lineJoin: .miter)
                )
                .frame(width: bigSide, height: bigSide)
                .position(x: bigCX, y: bigCY)
                .opacity(outlineOpacity)

            Rectangle()
                .fill(invertedForeground)
                .frame(width: notch, height: notch)
                .position(x: bigX + bigSide - notch / 2, y: bigY + notch / 2)
                .opacity(notchReveal)

            LCutShape(
                trimEnd: lCutTrim,
                startPoint: lStart,
                cornerPoint: lCorner,
                endPoint: lEnd
            )
            .stroke(
                invertedForeground,
                style: StrokeStyle(lineWidth: lStrokeW, lineCap: .square, lineJoin: .miter)
            )
            .frame(width: size, height: size)

            Rectangle()
                .fill(foreground)
                .frame(width: smallSide, height: smallSide)
                .scaleEffect(smallSquareScale)
                .position(x: smallCX, y: smallCY)
        }
        .frame(width: size, height: size)
    }

    // MARK: - Animation

    private func jumpToCompleted() {
        outlineTrim = 1.0
        outlineOpacity = 0
        fillOpacity = 1.0
        lCutTrim = 1.0
        notchReveal = 1.0
        smallSquareScale = 1.0
    }

    private func startAnimation() {
        withAnimation(.easeInOut(duration: 1.0)) {
            outlineTrim = 1.0
        }
        withAnimation(.easeIn(duration: 0.5).delay(1.0)) {
            fillOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.3).delay(1.4)) {
            outlineOpacity = 0
        }
        withAnimation(.easeInOut(duration: 0.8).delay(1.7)) {
            lCutTrim = 1.0
            notchReveal = 1.0
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6).delay(2.5)) {
            smallSquareScale = 1.0
        }
    }
}
