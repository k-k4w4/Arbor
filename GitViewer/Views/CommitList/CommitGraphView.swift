import SwiftUI

// Phase 5: Canvas-based commit graph lane renderer
struct CommitGraphView: View {
    let node: GraphNode

    private let rowHeight: CGFloat = 28
    private let laneWidth: CGFloat = 14
    private let nodeRadius: CGFloat = 4

    var body: some View {
        Canvas { context, size in
            let cy = size.height / 2

            // Draw lines
            for line in node.lines {
                let fromX = CGFloat(line.fromLane) * laneWidth + laneWidth / 2
                let toX = CGFloat(line.toLane) * laneWidth + laneWidth / 2
                var path = Path()
                path.move(to: CGPoint(x: fromX, y: 0))
                path.addCurve(
                    to: CGPoint(x: toX, y: size.height),
                    control1: CGPoint(x: fromX, y: size.height * 0.5),
                    control2: CGPoint(x: toX, y: size.height * 0.5)
                )
                context.stroke(path, with: .color(line.color), lineWidth: 2)
            }

            // Draw node dot
            let nodeX = CGFloat(node.lane) * laneWidth + laneWidth / 2
            let rect = CGRect(
                x: nodeX - nodeRadius, y: cy - nodeRadius,
                width: nodeRadius * 2, height: nodeRadius * 2
            )
            context.fill(Path(ellipseIn: rect), with: .color(node.dotColor))
        }
        .frame(width: CGFloat(max(1, node.totalLanes)) * laneWidth, height: rowHeight)
    }
}
