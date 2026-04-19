import SwiftUI

/// A waterfall/masonry grid layout that places items in the shortest column.
/// Uses the native SwiftUI Layout protocol for optimal performance.
struct WaterfallGrid: Layout {
    let columns: Int
    let spacing: CGFloat
    
    init(columns: Int = 3, spacing: CGFloat = 8) {
        self.columns = max(1, columns)
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let frames = calculateFrames(
            subviews: subviews,
            containerWidth: proposal.replacingUnspecifiedDimensions().width
        )
        
        let maxY = frames.map { $0.maxY }.max() ?? 0
        return CGSize(width: proposal.replacingUnspecifiedDimensions().width, height: maxY)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = calculateFrames(
            subviews: subviews,
            containerWidth: bounds.width
        )
        
        for (index, subview) in subviews.enumerated() {
            guard index < frames.count else { continue }
            let frame = frames[index]
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }
    
    private func calculateFrames(subviews: Subviews, containerWidth: CGFloat) -> [CGRect] {
        let columnWidth = (containerWidth - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        var columnHeights = Array(repeating: CGFloat.zero, count: columns)
        var frames: [CGRect] = []
        
        for subview in subviews {
            // Find the shortest column
            let shortestColumnIndex = columnHeights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            
            // Calculate item size
            let size = subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil))
            
            // Calculate position
            let x = CGFloat(shortestColumnIndex) * (columnWidth + spacing)
            let y = columnHeights[shortestColumnIndex]
            
            let frame = CGRect(x: x, y: y, width: columnWidth, height: size.height)
            frames.append(frame)
            
            // Update column height
            columnHeights[shortestColumnIndex] = y + size.height + spacing
        }
        
        return frames
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        WaterfallGrid(columns: 3, spacing: 8) {
            ForEach(0..<15) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(Double.random(in: 0.3...0.8)))
                    .frame(height: CGFloat.random(in: 80...200))
            }
        }
        .padding()
    }
}
