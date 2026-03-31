import Foundation

enum GraphLineType {
    case continuation
    case mergeIn
    case branchOut
}

struct GraphLine {
    var fromLane: Int
    var toLane: Int
    var type: GraphLineType
    var colorLane: Int  // lane index for color lookup; kept in model to avoid recomputing in View
}

struct GraphNode {
    var lane: Int
    var totalLanes: Int
    var lines: [GraphLine]
}
