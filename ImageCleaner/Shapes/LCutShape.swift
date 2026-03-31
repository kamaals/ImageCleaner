import SwiftUI

/// Draws an L-shaped line between three points: start → corner → end.
struct LCutShape: Shape {
    var trimEnd: CGFloat
    let startPoint: CGPoint
    let cornerPoint: CGPoint
    let endPoint: CGPoint

    var animatableData: CGFloat {
        get { trimEnd }
        set { trimEnd = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard trimEnd > 0 else { return path }

        let seg1Len = abs(cornerPoint.y - startPoint.y) + abs(cornerPoint.x - startPoint.x)
        let seg2Len = abs(endPoint.x - cornerPoint.x) + abs(endPoint.y - cornerPoint.y)
        let totalLen = seg1Len + seg2Len
        guard totalLen > 0 else { return path }

        let drawn = trimEnd * totalLen

        path.move(to: startPoint)

        if drawn <= seg1Len {
            let progress = drawn / seg1Len
            path.addLine(to: CGPoint(
                x: startPoint.x + (cornerPoint.x - startPoint.x) * progress,
                y: startPoint.y + (cornerPoint.y - startPoint.y) * progress
            ))
        } else {
            path.addLine(to: cornerPoint)
            let seg2Progress = (drawn - seg1Len) / seg2Len
            path.addLine(to: CGPoint(
                x: cornerPoint.x + (endPoint.x - cornerPoint.x) * seg2Progress,
                y: cornerPoint.y + (endPoint.y - cornerPoint.y) * seg2Progress
            ))
        }

        return path
    }
}
