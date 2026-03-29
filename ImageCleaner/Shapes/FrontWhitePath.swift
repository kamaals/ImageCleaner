//
//  FrontWhitePath.swift
//  Anima
//
//  Created by Kamaal ABOOTHALIB on 28/03/2026.
//

import SwiftUI

/// White segments of the front square border (overlapping edges).
/// Draws: crossX on bottom → bottom-left → crossY on left.
struct FrontWhitePath: Shape {
    var squareSide: CGFloat
    var crossX: CGFloat
    var crossY: CGFloat

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { .init(squareSide, .init(crossX, crossY)) }
        set {
            squareSide = newValue.first
            crossX = newValue.second.first
            crossY = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let cx = min(max(crossX, 0), squareSide)
        let cy = min(max(crossY, 0), squareSide)

        var p = Path()
        // Segment 3: crossX on bottom → bottom-left
        p.move(to: CGPoint(x: cx, y: squareSide))
        p.addLine(to: CGPoint(x: 0, y: squareSide))
        // Segment 4: bottom-left → crossY on left
        p.addLine(to: CGPoint(x: 0, y: cy))
        return p
    }
}
