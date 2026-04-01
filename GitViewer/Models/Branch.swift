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

    // Ref string suitable for passing to git log
    var gitRef: String {
        switch refType {
        case .localBranch:
            return shortName
        case .remoteBranch(let remote):
            return "\(remote)/\(shortName)"
        case .tag:
            return shortName
        case .stash:
            return name  // "stash@{0}"
        }
    }
}
