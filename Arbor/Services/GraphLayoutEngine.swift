import Foundation

struct GraphLayoutEngine {
    // Process only `commits` (new commits for this page) using the current `activeLanes` state.
    // `activeLanes` is updated in-place so subsequent calls continue from where this left off.
    static func compute(commits: inout [Commit], activeLanes: inout [String?]) {
        // SHA→lane dictionary for O(1) lookups; kept in sync with activeLanes throughout.
        // Use uniquingKeysWith to avoid a fatal trap if activeLanes somehow contains duplicate SHAs.
        var shaToLane: [String: Int] = Dictionary(
            activeLanes.enumerated().compactMap { i, s in s.map { ($0, i) } },
            uniquingKeysWith: { first, _ in first }
        )
        // IndexSet keeps free lane indices sorted and gives O(log n) insert + O(1) min-extraction.
        var freeLanes = IndexSet(activeLanes.indices.filter { activeLanes[$0] == nil })

        for i in 0..<commits.count {
            guard !Task.isCancelled else { return }
            let sha = commits[i].id
            let parents = commits[i].parentSHAs

            // Capture lane count and free-lane set before any modifications.
            // topFreeLanes (a small IndexSet, cheap to copy) lets the graph loop distinguish
            // free slots (nil at top-of-row) from pass-through slots without a full activeLanes copy.
            // topCount intentionally excludes a newly appended myLane (append path) — those lanes
            // didn't exist at top-of-row and are handled by the new-branch-tip section instead.
            let topCount = activeLanes.count
            let topFreeLanes = freeLanes

            // Find or assign the lane for this commit (O(1) with dict).
            let myLane: Int
            let wasTracked: Bool
            if let lane = shaToLane[sha] {
                myLane = lane
                wasTracked = true
            } else if let firstFree = freeLanes.first {
                myLane = firstFree
                freeLanes.remove(firstFree)
                activeLanes[myLane] = sha
                shaToLane[sha] = myLane
                wasTracked = false
            } else {
                myLane = activeLanes.count
                activeLanes.append(sha)
                shaToLane[sha] = myLane
                wasTracked = false
            }

            // What was at myLane at the TOP of this row (before modifications):
            // - wasTracked: sha was already there.
            // - !wasTracked: the slot was nil (free) or didn't exist (new append).
            let topMylaneValue: String? = wasTracked ? sha : nil

            // Advance activeLanes/shaToLane/freeLanes to bottom-of-row state in place,
            // avoiding the O(n) copy that a nextActiveLanes = activeLanes pattern would incur.
            if parents.isEmpty {
                activeLanes[myLane] = nil
                shaToLane.removeValue(forKey: sha)
                freeLanes.insert(myLane)
            } else {
                // First parent: if already tracked elsewhere, free myLane (branch convergence).
                if shaToLane[parents[0]] != nil {
                    activeLanes[myLane] = nil
                    shaToLane.removeValue(forKey: sha)
                    freeLanes.insert(myLane)
                } else {
                    activeLanes[myLane] = parents[0]
                    shaToLane.removeValue(forKey: sha)
                    shaToLane[parents[0]] = myLane
                }
                // Additional parents (merge commits): assign to free/new lanes.
                for k in 1..<parents.count {
                    let pSHA = parents[k]
                    if shaToLane[pSHA] == nil {
                        if let firstFree = freeLanes.first {
                            freeLanes.remove(firstFree)
                            activeLanes[firstFree] = pSHA
                            shaToLane[pSHA] = firstFree
                        } else {
                            let newLane = activeLanes.count
                            activeLanes.append(pSHA)
                            shaToLane[pSHA] = newLane
                        }
                    }
                }
            }

            // Generate GraphLines: map each SHA from its top-of-row lane to its bottom-of-row lane.
            // Avoids a full activeLanes copy: pass-through slots (non-nil at top-of-row) are
            // read directly from activeLanes (they're never modified). Free slots (topFreeLanes)
            // are treated as nil even if a new parent was assigned there after top-of-row.
            var lines: [GraphLine] = []
            for fromLane in 0..<topCount {
                let lSHA: String?
                if fromLane == myLane {
                    lSHA = topMylaneValue
                } else if topFreeLanes.contains(fromLane) {
                    lSHA = nil  // was a free (nil) slot at top-of-row
                } else {
                    lSHA = fromLane < activeLanes.count ? activeLanes[fromLane] : nil
                }
                guard let lSHA = lSHA else { continue }
                if lSHA == sha {
                    // Current commit: draw outgoing lines to parent lanes.
                    for pSHA in parents {
                        if let toLane = shaToLane[pSHA] {
                            let type: GraphLineType = toLane == fromLane ? .continuation : .mergeIn
                            lines.append(GraphLine(fromLane: fromLane, toLane: toLane, type: type, colorLane: fromLane))
                        }
                    }
                } else {
                    // Pass-through lane.
                    if let toLane = shaToLane[lSHA] {
                        let type: GraphLineType = fromLane == toLane ? .continuation : .branchOut
                        lines.append(GraphLine(fromLane: fromLane, toLane: toLane, type: type, colorLane: fromLane))
                    }
                }
            }
            // New branch tip: no incoming line, but add outgoing lines from myLane.
            if !wasTracked {
                for pSHA in parents {
                    if let toLane = shaToLane[pSHA] {
                        lines.append(GraphLine(fromLane: myLane, toLane: toLane, type: .continuation, colorLane: myLane))
                    }
                }
            }

            // activeLanes.count >= topLanes.count at this point (in-place updates only append).
            let totalLanes = max(activeLanes.count, 1)
            commits[i].graphNode = GraphNode(lane: myLane, totalLanes: totalLanes, lines: lines)

            // Trim trailing nil lanes to keep activeLanes compact.
            while activeLanes.last == nil {
                let removedIdx = activeLanes.count - 1
                activeLanes.removeLast()
                freeLanes.remove(removedIdx)
            }
        }
    }
}
