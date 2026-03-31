import Foundation

enum FileStatus: String, Hashable {
    case modified = "M"
    case added = "A"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
}

struct DiffFile: Identifiable {
    let id: String  // newPath as stable identifier
    var status: FileStatus
    var oldPath: String?
    var newPath: String
    var hunks: [DiffHunk]
    var isBinary: Bool

    init(status: FileStatus, oldPath: String? = nil, newPath: String, isBinary: Bool = false) {
        self.id = "\(status.rawValue)-\(newPath)"
        self.status = status
        self.oldPath = oldPath
        self.newPath = newPath
        self.hunks = []
        self.isBinary = isBinary
    }

    var displayPath: String { newPath }
}
