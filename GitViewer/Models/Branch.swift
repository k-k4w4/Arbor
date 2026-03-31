import Foundation

enum RefType: Hashable, Codable {
    case localBranch
    case remoteBranch(remote: String)
    case tag
    case stash(index: Int)
}

struct GitRef: Identifiable, Hashable {
    var name: String
    var shortName: String
    var sha: String
    var refType: RefType
    var isHead: Bool

    // Use full refname as stable ID so SwiftUI list doesn't re-render on refresh
    var id: String { name }

    init(name: String, shortName: String, sha: String, refType: RefType, isHead: Bool = false) {
        self.name = name
        self.shortName = shortName
        self.sha = sha
        self.refType = refType
        self.isHead = isHead
    }
}
