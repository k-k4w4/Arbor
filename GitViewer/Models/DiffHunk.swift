import Foundation

enum DiffLineType {
    case context
    case added
    case deleted
    case hunkHeader
}

struct DiffLine: Identifiable {
    // Stable ID: index within the hunk's lines array, prefixed by type.
    // Deterministic across re-parses so SwiftUI only re-renders changed lines.
    let id: String
    var type: DiffLineType
    var content: String
    var oldLineNumber: Int?
    var newLineNumber: Int?

    init(hunkIndex: Int, index: Int, type: DiffLineType, content: String, oldLineNumber: Int? = nil, newLineNumber: Int? = nil) {
        self.id = "\(hunkIndex)-\(type)-\(index)"
        self.type = type
        self.content = content
        self.oldLineNumber = oldLineNumber
        self.newLineNumber = newLineNumber
    }
}

struct DiffHunk: Identifiable {
    // Stable ID based on hunk position so SwiftUI can diff across re-parses
    var id: String { "\(oldStart)-\(newStart)-\(header)" }
    var header: String
    var oldStart: Int
    var oldCount: Int
    var newStart: Int
    var newCount: Int
    var lines: [DiffLine]

    init(header: String, oldStart: Int, oldCount: Int, newStart: Int, newCount: Int) {
        self.header = header
        self.oldStart = oldStart
        self.oldCount = oldCount
        self.newStart = newStart
        self.newCount = newCount
        self.lines = []
    }
}
