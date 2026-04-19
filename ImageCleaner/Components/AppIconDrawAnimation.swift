//
//  AppIconDrawAnimation.swift
//  ImageCleaner
//

import SwiftUI

/// Three-phase build-up animation of the ImageCleaner app icon.
///
/// 1. Back square (light gray) grows bottom → top.
/// 2. Bridge parallelogram sweeps out of the back square's top edge
///    diagonally down-right, with its top edge pinned to the back square's
///    top edge and its bottom corners tracing to their final positions.
///    Where the bridge overlaps the back square, alpha blending creates
///    the darker upper-right triangle.
/// 3. Front square (solid, black on light / white on dark) grows top → bottom.
///
/// Tap Replay to re-run. Respects Reduce Motion.
struct AppIconDrawAnimation: View {
    var backColor: Color
    var bridgeColor: Color
    var frontColor: Color
    var skipDrawAnimation: Bool
    var onFinished: (() -> Void)?

    @State private var backProgress: CGFloat = 0
    @State private var bridgeProgress: CGFloat = 0
    @State private var frontProgress: CGFloat = 0
    @State private var hasStarted = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        backColor: Color = Color(light: Color(white: 0.75), dark: Color(white: 0.50)),
        bridgeColor: Color = Color(light: .black.opacity(0.25), dark: .white.opacity(0.20)),
        frontColor: Color = Color(light: .black, dark: .white),
        skipDrawAnimation: Bool = false,
        onFinished: (() -> Void)? = nil
    ) {
        self.backColor = backColor
        self.bridgeColor = bridgeColor
        self.frontColor = frontColor
        self.skipDrawAnimation = skipDrawAnimation
        self.onFinished = onFinished
    }

    var body: some View {
        Button(action: replay) {
            ZStack {
                BackSquareShape(progress: backProgress).fill(backColor)
                BridgeShape(progress: bridgeProgress).fill(bridgeColor)
                FrontSquareShape(progress: frontProgress).fill(frontColor)
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("App icon")
        .accessibilityAddTraits(.isButton)
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            if skipDrawAnimation || reduceMotion {
                showFinalState()
            } else {
                await play()
            }
        }
    }

    /// Sequential phase animation. Using `Task.sleep` between phases instead
    /// of nested `withAnimation { } completion:` closures is more reliable on
    /// real devices where completion callbacks can be swallowed when they
    /// land on a busy main queue.
    private func play() async {
        reset()

        withAnimation(.easeOut(duration: 0.55)) { backProgress = 1 }
        try? await Task.sleep(for: .milliseconds(550))

        withAnimation(.easeInOut(duration: 0.6)) { bridgeProgress = 1 }
        try? await Task.sleep(for: .milliseconds(600))

        withAnimation(.easeOut(duration: 0.55)) { frontProgress = 1 }
        try? await Task.sleep(for: .milliseconds(550))

        onFinished?()
    }

    private func showFinalState() {
        backProgress = 1
        bridgeProgress = 1
        frontProgress = 1
        onFinished?()
    }

    private func reset() {
        backProgress = 0
        bridgeProgress = 0
        frontProgress = 0
    }

    private func replay() {
        guard !reduceMotion else { return }
        reset()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            await play()
        }
    }
}

// MARK: - Design coordinates

/// Icon geometry in a 1000×1000 design coordinate system. All three pieces
/// share the same side length; the front square is offset diagonally by one
/// side so the back's bottom-right corner coincides with the front's
/// top-left. The bridge parallelogram anchors its top edge to the back
/// square's top edge, and its bottom-left to the shared corner.
private enum IconGeometry {
    static let canvas: CGFloat = 1000
    static let squareSide: CGFloat = 300

    // Back square — top-left corner.
    static let backTL = CGPoint(x: 200, y: 200)
    // Front square — top-left corner (= back's bottom-right corner).
    static let frontTL = CGPoint(x: 500, y: 500)

    // Bridge parallelogram corners (clockwise from top-left).
    static let bridgeTL = CGPoint(x: 200, y: 200) // = back.TL
    static let bridgeTR = CGPoint(x: 500, y: 200) // = back.TR
    static let bridgeBR = CGPoint(x: 800, y: 500) // = front.TR
    static let bridgeBL = CGPoint(x: 500, y: 500) // = back.BR = front.TL
}

// MARK: - Shape helpers

private func scaleFactor(for rect: CGRect) -> CGFloat {
    min(rect.width, rect.height) / IconGeometry.canvas
}

private func scaled(_ point: CGPoint, in rect: CGRect) -> CGPoint {
    let s = scaleFactor(for: rect)
    return CGPoint(x: point.x * s, y: point.y * s)
}

private func lerp(from a: CGPoint, to b: CGPoint, t: CGFloat) -> CGPoint {
    CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
}

// MARK: - Shapes

/// Back square. Grows bottom → top: bottom edge pinned, top edge rises.
private struct BackSquareShape: Shape {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func path(in rect: CGRect) -> Path {
        let s = scaleFactor(for: rect)
        let side = IconGeometry.squareSide * s
        let tl = scaled(IconGeometry.backTL, in: rect)
        let bottomY = tl.y + side
        let currentHeight = side * progress
        return Path(CGRect(
            x: tl.x,
            y: bottomY - currentHeight,
            width: side,
            height: currentHeight
        ))
    }
}

/// Front square. Grows top → bottom: top edge pinned, bottom edge descends.
private struct FrontSquareShape: Shape {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func path(in rect: CGRect) -> Path {
        let s = scaleFactor(for: rect)
        let side = IconGeometry.squareSide * s
        let tl = scaled(IconGeometry.frontTL, in: rect)
        return Path(CGRect(
            x: tl.x,
            y: tl.y,
            width: side,
            height: side * progress
        ))
    }
}

/// Bridge parallelogram. Top edge pinned to the back square's top edge;
/// bottom corners slide diagonally from the top corners down to their
/// final positions, sweeping the parallelogram into existence along the
/// skew direction.
private struct BridgeShape: Shape {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func path(in rect: CGRect) -> Path {
        let tl = scaled(IconGeometry.bridgeTL, in: rect)
        let tr = scaled(IconGeometry.bridgeTR, in: rect)
        let bl = lerp(from: tl, to: scaled(IconGeometry.bridgeBL, in: rect), t: progress)
        let br = lerp(from: tr, to: scaled(IconGeometry.bridgeBR, in: rect), t: progress)

        var path = Path()
        path.move(to: tl)
        path.addLine(to: tr)
        path.addLine(to: br)
        path.addLine(to: bl)
        path.closeSubpath()
        return path
    }
}

#Preview("Icon draw — light") {
    AppIconDrawAnimation()
        .frame(width: 280, height: 280)
        .padding(32)
        .preferredColorScheme(.light)
}

#Preview("Icon draw — dark") {
    AppIconDrawAnimation()
        .frame(width: 280, height: 280)
        .padding(32)
        .preferredColorScheme(.dark)
}

#Preview("Icon draw — size scale") {
    // Confirms the layout holds at small, medium, and large frames.
    VStack(spacing: 24) {
        AppIconDrawAnimation().frame(width: 64, height: 64)
        AppIconDrawAnimation().frame(width: 140, height: 140)
        AppIconDrawAnimation().frame(width: 260, height: 260)
    }
    .padding()
}
