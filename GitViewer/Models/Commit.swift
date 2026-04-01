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
}
