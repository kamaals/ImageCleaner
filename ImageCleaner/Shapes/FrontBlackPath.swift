//
//  FrontBlackPath.swift
//  Anima
//
//  Created by Kamaal ABOOTHALIB on 28/03/2026.
//

import SwiftUI

/// Black segments of the front square border (non-overlapping edges).
/// Draws: top-right → bottom-right → crossX on bottom, then crossY on left → top-left → top-right.
struct FrontBlackPath: Shape {
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
        // Clamp cross points within the square
        let cx = min(max(crossX, 0), squareSide)
        let cy = min(max(crossY, 0), squareSide)

        var p = Path()
        // Segment 1: top-right → bottom-right (right edge)
        p.move(to: CGPoint(x: squareSide, y: 0))
        p.addLine(to: CGPoint(x: squareSide, y: squareSide))
        // Segment 2: bottom-right → crossX on bottom edge
        p.addLine(to: CGPoint(x: cx, y: squareSide))
        // Gap — white path takes over here
        // Segment 5: crossY on left edge → top-left
        p.move(to: CGPoint(x: 0, y: cy))
        p.addLine(to: CGPoint(x: 0, y: 0))
        // Segment 6: top-left → top-right (top edge)
        p.addLine(to: CGPoint(x: squareSide, y: 0))
        return p
    }
}
