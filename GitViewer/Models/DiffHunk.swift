import Foundation

enum DiffLineType {
    case context
    case added
    case deleted
    case hunkHeader
}

struct DiffLine: Identifiable {
    let id: UUID
    var type: DiffLineType
    var content: String
    var oldLineNumber: Int?
    var newLineNumber: Int?

    init(type: DiffLineType, content: String, oldLineNumber: Int? = nil, newLineNumber: Int? = nil) {
        self.id = UUID()
        self.type = type
        self.content = content
        self.oldLineNumber = oldLineNumber
        self.newLineNumber = newLineNumber
    }
}

struct DiffHunk: Identifiable {
    let id: UUID
    var header: String
    var oldStart: Int
    var oldCount: Int
    var newStart: Int
    var newCount: Int
    var lines: [DiffLine]

    init(header: String, oldStart: Int, oldCount: Int, newStart: Int, newCount: Int) {
        self.id = UUID()
        self.header = header
        self.oldStart = oldStart
        self.oldCount = oldCount
        self.newStart = newStart
        self.newCount = newCount
        self.lines = []
    }
}
