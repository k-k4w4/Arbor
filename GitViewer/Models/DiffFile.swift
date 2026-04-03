import Foundation

enum FileStatus: String, Hashable {
    case modified = "M"
    case added = "A"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
    case typeChanged = "T"
    case unmerged = "U"
    case untracked = "?"
}

struct DiffFile: Identifiable {
    let id: String
    var status: FileStatus
    var oldPath: String?
    var newPath: String
    var rawNewPath: Data    // original bytes for passing to git commands
    var rawOldPath: Data?
    var hunks: [DiffHunk]
    var isBinary: Bool
    var staged: Bool?       // nil = committed diff; true = staged area; false = working tree

    init(status: FileStatus, oldPath: String? = nil, newPath: String,
         rawOldPath: Data? = nil, rawNewPath: Data, isBinary: Bool = false, staged: Bool? = nil) {
        // Include staged flag in id so staged+unstaged versions of the same path are distinct.
        let stagedTag = staged.map { $0 ? "S" : "U" } ?? "C"
        self.id = "\(status.rawValue):\(stagedTag):\(oldPath ?? ""):\(newPath)"
        self.status = status
        self.oldPath = oldPath
        self.newPath = newPath
        self.rawNewPath = rawNewPath
        self.rawOldPath = rawOldPath
        self.hunks = []
        self.isBinary = isBinary
        self.staged = staged
    }

    var displayPath: String { newPath }
}
