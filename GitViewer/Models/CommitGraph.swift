import SwiftUI

enum GraphLineType {
    case continuation
    case mergeIn
    case branchOut
}

struct GraphLine {
    var fromLane: Int
    var toLane: Int
    var type: GraphLineType
    var color: Color
}

struct GraphNode {
    var lane: Int
    var totalLanes: Int
    var lines: [GraphLine]
    var dotColor: Color
}
