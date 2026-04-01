import XCTest
@testable import GitViewer

final class GraphLayoutEngineTests: XCTestCase {

    // GraphLayoutEngine only compares SHA strings, so any distinct strings work.
    private let shaA = String(repeating: "a", count: 40)
    private let shaB = String(repeating: "b", count: 40)
    private let shaC = String(repeating: "c", count: 40)
    private let shaD = String(repeating: "d", count: 40)

    private func makeCommit(_ sha: String, parents: [String] = []) -> Commit {
        Commit(
            id: sha, shortSHA: String(sha.prefix(7)), parentSHAs: parents,
            subject: "msg", message: "msg",
            authorName: "A", authorEmail: "a@a.com", authorDate: Date(),
            committerName: "A", committerEmail: "a@a.com", committerDate: Date(),
            refs: []
        )
    }

    private func run(_ commits: inout [Commit], lanes: inout [String?]) {
        GraphLayoutEngine.compute(commits: &commits, activeLanes: &lanes)
    }

    // MARK: - Single commit

    func testSingleRootCommitLaneZero() {
        var commits = [makeCommit(shaA)]
        var lanes: [String?] = []
        run(&commits, lanes: &lanes)

        XCTAssertEqual(commits[0].graphNode?.lane, 0)
    }

    func testSingleRootCommitNoLines() {
        var commits = [makeCommit(shaA)]
        var lanes: [String?] = []
        run(&commits, lanes: &lanes)

        XCTAssertEqual(commits[0].graphNode?.lines.count, 0)
    }

    func testSingleRootCommitNoActiveSHAs() {
        var commits = [makeCommit(shaA)]
        var lanes: [String?] = []
        run(&commits, lanes: &lanes)

        // After a root commit all lanes should be nil (no SHAs being tracked).
        // Note: trailing nil elements may remain due to Swift [String?] trim semantics.
        XCTAssertTrue(lanes.filter { $0 != nil }.isEmpty)
    }

    // MARK: - Linear chain (A ← B ← C, newest first)

    func testLinearChainAllOnLaneZero() {
        var commits = [
            makeCommit(shaC, parents: [shaB]),
            makeCommit(shaB, parents: [shaA]),
            makeCommit(shaA)
        ]
        var lanes: [String?] = []
        run(&commits, lanes: &lanes)

        XCTAssertEqual(commits[0].graphNode?.lane, 0)
        XCTAssertEqual(commits[1].graphNode?.lane, 0)
        XCTAssertEqual(commits[2].graphNode?.lane, 0)
    }

    func testLinearChainNonRootHasContinuationLine() {
        var commits = [
            makeCommit(shaB, parents: [shaA]),
            makeCommit(shaA)
        ]
        var lanes: [String?] = []
        run(&commits, lanes: &lanes)

        let lines = commits[0].graphNode?.lines ?? []
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].fromLane, 0)
        XCTAssertEqual(lines[0].toLane, 0)
        XCTAssertEqual(lines[0].type, .continuation)
    }

    func testLinearChainRootHasNoLines() {
        var commits = [
            makeCommit(shaB, parents: [shaA]),
            makeCommit(shaA)
        ]
        var lanes: [String?] = []
        run(&commits, lanes: &lanes)

        XCTAssertEqual(commits[1].graphNode?.lines.count, 0)
    }

    func testLinearChainNoActiveSHAsAfterRoot() {
        var commits = [
            makeCommit(shaB, parents: [shaA]),
            makeCommit(shaA)
        ]
        var lanes: [String?] = []
        run(&commits, lanes: &lanes)

        XCTAssertTrue(lanes.filter { $0 != nil }.isEmpty)
    }

    // MARK: - Merge commit (diamond: M←{A,B}, A←root, B←root)

    //  M (lane 0, parents: A, B)
    //  |\
    //  A B
    //  |/
    //  root

    func testMergeCommitOnLaneZero() {
        var commits = [
            makeCommit(shaA, parents: [shaB, shaC]),  // merge
            makeCommit(shaB, parents: [shaD]),         // main
            makeCommit(shaC, parents: [shaD]),         // feature
            makeCommit(shaD)                           // root
        ]
        var lanes: [String?] = []
        run(&commits, lanes: &lanes)

        XCTAssertEqual(commits[0].graphNode?.lane, 0)
    }

    func testMergeCommitCreatesTwoOutgoingLines() {
        var commits = [
            makeCommit(shaA, parents: [shaB, shaC]),
            makeCommit(shaB, parents: [shaD]),
            makeCommit(shaC, parents: [shaD]),
            makeCommit(shaD)
        ]
        var lanes: [String?] = []
        run(&commits, lanes: &lanes)

        let lines = commits[0].graphNode?.lines ?? []
        XCTAssertEqual(lines.count, 2)
        // First parent (main) stays on lane 0
        XCTAssertTrue(lines.contains(where: { $0.fromLane == 0 && $0.toLane == 0 }))
        // Second parent (feature branch) goes to lane 1
        XCTAssertTrue(lines.contains(where: { $0.fromLane == 0 && $0.toLane == 1 }))
    }

    func testFeatureBranchOnLaneOne() {
        var commits = [
            makeCommit(shaA, parents: [shaB, shaC]),
            makeCommit(shaB, parents: [shaD]),
            makeCommit(shaC, parents: [shaD]),
            makeCommit(shaD)
        ]
        var lanes: [String?] = []
        run(&commits, lanes: &lanes)

        // shaC (feature branch) should be placed at lane 1
        XCTAssertEqual(commits[2].graphNode?.lane, 1)
    }

    func testDiamondMergeNoActiveSHAsAfterRoot() {
        var commits = [
            makeCommit(shaA, parents: [shaB, shaC]),
            makeCommit(shaB, parents: [shaD]),
            makeCommit(shaC, parents: [shaD]),
            makeCommit(shaD)
        ]
        var lanes: [String?] = []
        run(&commits, lanes: &lanes)

        XCTAssertTrue(lanes.filter { $0 != nil }.isEmpty)
    }

    // MARK: - Two independent branches (no merge yet)

    // Branch tip B appears in the commit list but hasn't merged into main yet.
    // activeLanes after processing [A(parent:root), B(parent:root)]
    // should contain both parents pointing to root (or nil if root already tracked).

    func testBranchTipAssignedNewLane() {
        // Simulates two branch tips before their common ancestor
        var commits = [
            makeCommit(shaA, parents: [shaC]),  // main tip
            makeCommit(shaB, parents: [shaC]),  // feature tip
        ]
        var lanes: [String?] = []
        run(&commits, lanes: &lanes)

        // A gets lane 0, B gets lane 1
        XCTAssertEqual(commits[0].graphNode?.lane, 0)
        XCTAssertEqual(commits[1].graphNode?.lane, 1)
    }

    // MARK: - Incremental paging

    func testIncrementalPageContinuesLaneState() {
        // Page 1: just the top commit, parent is shaB
        var page1 = [makeCommit(shaA, parents: [shaB])]
        var lanes: [String?] = []
        GraphLayoutEngine.compute(commits: &page1, activeLanes: &lanes)

        // lanes should now track shaB at lane 0
        XCTAssertEqual(lanes, [shaB])

        // Page 2: shaB with parent shaC
        var page2 = [makeCommit(shaB, parents: [shaC])]
        GraphLayoutEngine.compute(commits: &page2, activeLanes: &lanes)

        // shaB should be resolved at lane 0 (was already tracked)
        XCTAssertEqual(page2[0].graphNode?.lane, 0)
    }

    // MARK: - totalLanes

    func testTotalLanesReflectsMaxWidth() {
        var commits = [
            makeCommit(shaA, parents: [shaC, shaD]),  // merge: opens lanes for C and D
            makeCommit(shaC, parents: [shaB]),
            makeCommit(shaD, parents: [shaB]),
            makeCommit(shaB)
        ]
        var lanes: [String?] = []
        run(&commits, lanes: &lanes)

        // At some point we need 2 lanes simultaneously
        let maxLanes = commits.compactMap { $0.graphNode?.totalLanes }.max() ?? 0
        XCTAssertGreaterThanOrEqual(maxLanes, 2)
    }

    func testSingleBranchTotalLanesIsOne() {
        var commits = [
            makeCommit(shaB, parents: [shaA]),
            makeCommit(shaA)
        ]
        var lanes: [String?] = []
        run(&commits, lanes: &lanes)

        XCTAssertEqual(commits[0].graphNode?.totalLanes, 1)
        XCTAssertEqual(commits[1].graphNode?.totalLanes, 1)
    }
}
