import Foundation

enum FileStatus: String, Hashable {
    case modified = "M"
    case added = "A"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
    case typeChanged = "T"
    case unmerged = "U"
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

    init(status: FileStatus, oldPath: String? = nil, newPath: String,
         rawOldPath: Data? = nil, rawNewPath: Data, isBinary: Bool = false) {
        self.id = "\(status.rawValue):\(oldPath ?? ""):\(newPath)"
        self.status = status
        self.oldPath = oldPath
        self.newPath = newPath
        self.rawNewPath = rawNewPath
        self.rawOldPath = rawOldPath
        self.hunks = []
        self.isBinary = isBinary
    }

    var displayPath: String { newPath }
}
