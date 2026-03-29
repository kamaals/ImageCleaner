//
//  AppIconView.swift
//  ImageCleaner
//

import SwiftUI

/// Animated app icon — solid back square (lower-left) overlapped by a transparent
/// front square (upper-right). The front square's border switches color at the
/// intersection points: foreground on non-overlapping edges, invertedForeground on overlap.
struct AppIconView: View {
    var foreground: Color = .black
    var invertedForeground: Color = .white

    @State private var backTrim: CGFloat = 0
    @State private var backFillOpacity: Double = 0
    @State private var frontBlackTrim: CGFloat = 0
    @State private var frontWhiteTrim: CGFloat = 0
    @State private var offsetProgress: CGFloat = 0
    @State private var hasAppeared = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let designSize: CGFloat = 200

    var body: some View {
        Button(action: replayAnimation) {
            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)

                iconLayers(for: size)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("App icon")
        .task {
            guard !hasAppeared else { return }
            hasAppeared = true
            startAnimation()
        }
    }

    // MARK: - Icon Composition

    private func iconLayers(for size: CGFloat) -> some View {
        let s = size / Self.designSize

        let squareSide: CGFloat = 140 * s
        let maxOffset: CGFloat  = 22 * s
        let borderW: CGFloat    = max(4 * s, 1.0)
        let currentOffset       = offsetProgress * maxOffset

        let strokeStyle = StrokeStyle(lineWidth: borderW, lineCap: .square, lineJoin: .miter)

        let crossX = squareSide - 2 * currentOffset
        let crossY = 2 * currentOffset

        return ZStack {
            Rectangle()
                .fill(foreground)
                .frame(width: squareSide, height: squareSide)
                .offset(x: -currentOffset, y: currentOffset)
                .opacity(backFillOpacity)

            Rectangle()
                .trim(from: 0, to: backTrim)
                .stroke(foreground, style: strokeStyle)
                .frame(width: squareSide, height: squareSide)
                .offset(x: -currentOffset, y: currentOffset)

            FrontBlackPath(squareSide: squareSide, crossX: crossX, crossY: crossY)
                .trim(from: 0, to: frontBlackTrim)
                .stroke(foreground, style: strokeStyle)
                .frame(width: squareSide, height: squareSide)
                .offset(x: currentOffset, y: -currentOffset)

            FrontWhitePath(squareSide: squareSide, crossX: crossX, crossY: crossY)
                .trim(from: 0, to: frontWhiteTrim)
                .stroke(invertedForeground, style: strokeStyle)
                .frame(width: squareSide, height: squareSide)
                .offset(x: currentOffset, y: -currentOffset)
        }
        .frame(width: size, height: size)
    }

    // MARK: - Animation Sequence

    private func startAnimation() {
        if reduceMotion {
            backTrim = 1.0
            backFillOpacity = 1.0
            frontBlackTrim = 1.0
            frontWhiteTrim = 1.0
            offsetProgress = 1.0
            return
        }

        withAnimation(.easeInOut(duration: 1.0)) {
            backTrim = 1.0
        } completion: {
            withAnimation(.easeIn(duration: 0.5)) {
                backFillOpacity = 1.0
            }
        }

        withAnimation(.easeInOut(duration: 0.8).delay(1.2)) {
            frontBlackTrim = 1.0
        } completion: {
            withAnimation(.easeInOut(duration: 0.6)) {
                frontWhiteTrim = 1.0
            } completion: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    offsetProgress = 1.0
                }
            }
        }
    }

    private func replayAnimation() {
        backTrim = 0
        backFillOpacity = 0
        frontBlackTrim = 0
        frontWhiteTrim = 0
        offsetProgress = 0

        Task {
            try? await Task.sleep(for: .milliseconds(150))
            startAnimation()
        }
    }
}

#Preview {
    AppIconView()
        .frame(width: 200, height: 200)
}
