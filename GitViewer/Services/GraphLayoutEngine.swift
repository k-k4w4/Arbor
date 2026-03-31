import Foundation

struct GraphLayoutEngine {
    // Process only `commits` (new commits for this page) using the current `activeLanes` state.
    // `activeLanes` is updated in-place so subsequent calls continue from where this left off.
    static func compute(commits: inout [Commit], activeLanes: inout [String?]) {
        for i in 0..<commits.count {
            let sha = commits[i].id
            let parents = commits[i].parentSHAs

            // Snapshot of lanes at the TOP of this row (before assigning myLane)
            let topLanes = activeLanes

            // Find or assign the lane for this commit
            let myLane: Int
            let wasTracked: Bool
            if let lane = activeLanes.firstIndex(where: { $0 == sha }) {
                myLane = lane
                wasTracked = true
            } else if let emptyLane = activeLanes.firstIndex(where: { $0 == nil }) {
                myLane = emptyLane
                activeLanes[myLane] = sha
                wasTracked = false
            } else {
                myLane = activeLanes.count
                activeLanes.append(sha)
                wasTracked = false
            }

            // Build nextActiveLanes (state at the BOTTOM of this row)
            var nextActiveLanes = activeLanes
            if parents.isEmpty {
                nextActiveLanes[myLane] = nil
            } else {
                // First parent: if already tracked elsewhere, free myLane (branch convergence)
                if nextActiveLanes.contains(where: { $0 == parents[0] }) {
                    nextActiveLanes[myLane] = nil
                } else {
                    nextActiveLanes[myLane] = parents[0]
                }
                // Additional parents (merge commits): assign to empty/new lanes
                for k in 1..<parents.count {
                    let pSHA = parents[k]
                    if !nextActiveLanes.contains(where: { $0 == pSHA }) {
                        if let emptyLane = nextActiveLanes.firstIndex(where: { $0 == nil }) {
                            nextActiveLanes[emptyLane] = pSHA
                        } else {
                            nextActiveLanes.append(pSHA)
                        }
                    }
                }
            }

            // Generate GraphLines: map each SHA from its top-of-row lane to its bottom-of-row lane
            var lines: [GraphLine] = []

            for fromLane in 0..<topLanes.count {
                guard let lSHA = topLanes[fromLane] else { continue }

                if lSHA == sha {
                    // Current commit: draw outgoing lines to parent lanes
                    for pSHA in parents {
                        if let toLane = nextActiveLanes.firstIndex(where: { $0 == pSHA }) {
                            let type: GraphLineType = toLane == fromLane ? .continuation : .mergeIn
                            lines.append(GraphLine(fromLane: fromLane, toLane: toLane, type: type, colorLane: fromLane))
                        }
                    }
                } else {
                    // Pass-through lane
                    if let toLane = nextActiveLanes.firstIndex(where: { $0 == lSHA }) {
                        let type: GraphLineType = fromLane == toLane ? .continuation : .branchOut
                        lines.append(GraphLine(fromLane: fromLane, toLane: toLane, type: type, colorLane: fromLane))
                    }
                }
            }

            // New branch tip: no incoming line, but add outgoing lines from myLane
            if !wasTracked {
                for pSHA in parents {
                    if let toLane = nextActiveLanes.firstIndex(where: { $0 == pSHA }) {
                        lines.append(GraphLine(fromLane: myLane, toLane: toLane, type: .continuation, colorLane: myLane))
                    }
                }
            }

            let totalLanes = max(activeLanes.count, nextActiveLanes.count, 1)
            commits[i].graphNode = GraphNode(lane: myLane, totalLanes: totalLanes, lines: lines)

            activeLanes = nextActiveLanes
            while activeLanes.last == nil {
                activeLanes.removeLast()
            }
        }
    }
}
