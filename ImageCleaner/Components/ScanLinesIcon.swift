import SwiftUI

/// Animated icon with horizontal lines overlapping a black square.
/// Scales to any frame size. Use like: `ScanLinesIcon().frame(width: 60, height: 60)`
struct ScanLinesIcon: View {
    var foreground: Color = .primary
    var invertedForeground: Color = .white
    var skipAnimation = false

    @State private var outlineTrim: CGFloat = 0
    @State private var fillOpacity: Double = 0
    @State private var offsetProgress: CGFloat = 0
    @State private var lineGrowth: CGFloat = 0
    @State private var hasAppeared = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let designSize: CGFloat = 340

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)

            vectorLayers(for: size)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Scan lines icon")
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

    private func vectorLayers(for size: CGFloat) -> some View {
        let scale = size / Self.designSize

        let squareSize    = 210 * scale
        let linesRectSize = 220 * scale
        let maxOffset     = 30 * scale
        let baseSpacing   = max(8 * scale, 2.0)
        let lineWidth     = max(2.5 * scale, 0.75)
        let borderWidth   = max(2.5 * scale, 0.75)
        let currentOffset = offsetProgress * maxOffset

        let lineStyle = StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
        let borderStyle = StrokeStyle(lineWidth: borderWidth, lineCap: .square, lineJoin: .miter)

        return ZStack {
            invertedForeground

            Rectangle()
                .fill(foreground)
                .frame(width: squareSize, height: squareSize)
                .offset(x: -currentOffset, y: currentOffset)
                .opacity(fillOpacity)

            Rectangle()
                .trim(from: 0, to: outlineTrim)
                .stroke(foreground, style: borderStyle)
                .frame(width: squareSize, height: squareSize)
                .offset(x: -currentOffset, y: currentOffset)

            HorizontalLinesShape(growth: lineGrowth, groupSpacing: baseSpacing * 2, yStart: baseSpacing)
                .stroke(foreground, style: lineStyle)
                .frame(width: linesRectSize, height: linesRectSize)
                .clipped()
                .offset(x: currentOffset, y: -currentOffset)

            HorizontalLinesShape(growth: lineGrowth, groupSpacing: baseSpacing * 2, yStart: 0)
                .stroke(.white, style: lineStyle)
                .frame(width: linesRectSize, height: linesRectSize)
                .clipped()
                .offset(x: currentOffset, y: -currentOffset)
                .blendMode(.difference)
        }
        .frame(width: size, height: size)
        .compositingGroup()
    }

    private func jumpToCompleted() {
        outlineTrim = 1.0
        fillOpacity = 1.0
        offsetProgress = 1.0
        lineGrowth = 1.0
    }

    private func startAnimation() {
        withAnimation(.easeInOut(duration: 1.0)) { outlineTrim = 1.0 }
        withAnimation(.easeIn(duration: 0.5).delay(1.0)) { fillOpacity = 1.0 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(1.3)) { offsetProgress = 1.0 }
        withAnimation(.easeInOut(duration: 1.8).delay(2.0)) { lineGrowth = 1.0 }
    }
}
