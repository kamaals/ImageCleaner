import SwiftUI

/// Draws one group of evenly-spaced horizontal lines (every-other-line of the full set).
/// Each line draws from RIGHT to LEFT with a top-to-bottom stagger cascade.
struct HorizontalLinesShape: Shape {
    var growth: CGFloat
    let groupSpacing: CGFloat
    let yStart: CGFloat

    var animatableData: CGFloat {
        get { growth }
        set { growth = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        struct Line {
            let rightEnd: CGPoint
            let leftEnd: CGPoint
        }

        var lines: [Line] = []
        var y = yStart
        while y <= rect.height {
            lines.append(Line(
                rightEnd: CGPoint(x: rect.maxX, y: y),
                leftEnd: CGPoint(x: rect.minX, y: y)
            ))
            y += groupSpacing
        }

        guard !lines.isEmpty else { return path }

        let staggerSpread: CGFloat = 0.55
        let lineDuration: CGFloat = 1.0 - staggerSpread
        let count = CGFloat(lines.count)

        for (index, line) in lines.enumerated() {
            let normalizedPosition = CGFloat(index) / max(count - 1, 1)
            let delay = normalizedPosition * staggerSpread
            let lineProgress = min(max((growth - delay) / lineDuration, 0), 1)

            guard lineProgress > 0 else { continue }

            let currentEnd = CGPoint(
                x: line.rightEnd.x + (line.leftEnd.x - line.rightEnd.x) * lineProgress,
                y: line.rightEnd.y
            )

            path.move(to: line.rightEnd)
            path.addLine(to: currentEnd)
        }

        return path
    }
}
