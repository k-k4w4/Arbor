import Foundation

struct Commit: Identifiable, Hashable {
    let id: String       // Full SHA (40 chars)
    var shortSHA: String // First 7 chars
    var parentSHAs: [String]
    var subject: String  // First line of message
    var message: String  // Full message
    var authorName: String
    var authorEmail: String
    var authorDate: Date
    var committerName: String
    var committerEmail: String
    var committerDate: Date
    var refs: [GitRef]
    var graphNode: GraphNode?

    static func == (lhs: Commit, rhs: Commit) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Working tree sentinel

    // Synthetic ID that cannot appear in real git history.
    static let workingTreeSentinelID = "0000000000000000000000000000000000000000"

    var isWorkingTreeSentinel: Bool { id == Commit.workingTreeSentinelID }

    static func makeWorkingTreeSentinel(fileCount: Int = 0) -> Commit {
        let subject = fileCount > 0 ? "作業中の変更 (\(fileCount)件)" : "作業中の変更"
        return Commit(
            id: workingTreeSentinelID,
            shortSHA: "",
            parentSHAs: [],
            subject: subject,
            message: "",
            authorName: "",
            authorEmail: "",
            authorDate: Date(),
            committerName: "",
            committerEmail: "",
            committerDate: Date(),
            refs: []
        )
    }
}
