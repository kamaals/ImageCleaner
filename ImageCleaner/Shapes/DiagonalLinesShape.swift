import SwiftUI

/// Custom shape that draws evenly-spaced 45° diagonal lines.
/// Each line draws from its top-right endpoint toward its bottom-left endpoint,
/// with a stagger cascade: rightmost lines start first, sweeping left.
struct DiagonalLinesShape: Shape {
    var growth: CGFloat
    var spacing: CGFloat

    var animatableData: CGFloat {
        get { growth }
        set { growth = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        struct Line {
            let topRight: CGPoint
            let bottomLeft: CGPoint
        }

        var lines: [Line] = []
        var x: CGFloat = -rect.height
        while x <= rect.width + rect.height {
            let bottomLeft = CGPoint(x: x, y: rect.maxY)
            let topRight   = CGPoint(x: x + rect.height, y: rect.minY)
            lines.append(Line(topRight: topRight, bottomLeft: bottomLeft))
            x += spacing
        }

        guard !lines.isEmpty else { return path }

        let staggerSpread: CGFloat = 0.55
        let lineDuration: CGFloat = 1.0 - staggerSpread
        let count = CGFloat(lines.count)

        for (index, line) in lines.enumerated() {
            let normalizedPosition = CGFloat(lines.count - 1 - index) / max(count - 1, 1)
            let delay = normalizedPosition * staggerSpread
            let lineProgress = min(max((growth - delay) / lineDuration, 0), 1)

            guard lineProgress > 0 else { continue }

            let currentEnd = CGPoint(
                x: line.topRight.x + (line.bottomLeft.x - line.topRight.x) * lineProgress,
                y: line.topRight.y + (line.bottomLeft.y - line.topRight.y) * lineProgress
            )

            path.move(to: line.topRight)
            path.addLine(to: currentEnd)
        }

        return path
    }
}
