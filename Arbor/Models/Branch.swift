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
    var ahead: Int = 0
    var behind: Int = 0

    // Use full refname as stable ID so SwiftUI list doesn't re-render on refresh
    var id: String { name }

    init(name: String, shortName: String, sha: String, refType: RefType, isHead: Bool = false, ahead: Int = 0, behind: Int = 0) {
        self.name = name
        self.shortName = shortName
        self.sha = sha
        self.refType = refType
        self.isHead = isHead
        self.ahead = ahead
        self.behind = behind
    }

    var toolbarIcon: String {
        switch refType {
        case .localBranch:  return "arrow.triangle.branch"
        case .remoteBranch: return "cloud"
        case .tag:          return "tag"
        case .stash:        return "archivebox"
        }
    }

    // Fully-qualified ref string for git commands.
    // Using the full name avoids ambiguity when a tag and a branch share the same shortName.
    var gitRef: String { name }
}
