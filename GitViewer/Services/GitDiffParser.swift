import Foundation

struct GitDiffParser {
    // Fixed pattern: always valid, force-unwrap is safe here
    private static let hunkRegex = try! NSRegularExpression(
        pattern: #"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@"#
    )

    static func parseNameStatus(_ output: String) -> [DiffFile] {
        var files: [DiffFile] = []
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.components(separatedBy: "\t")
            guard parts.count >= 2 else { continue }
            let code = parts[0]

            if code.hasPrefix("R") || code.hasPrefix("C") {
                guard parts.count >= 3 else { continue }
                let s: FileStatus = code.hasPrefix("R") ? .renamed : .copied
                files.append(DiffFile(status: s, oldPath: parts[1], newPath: parts[2]))
            } else if let s = status(from: code) {
                files.append(DiffFile(status: s, newPath: parts[1]))
            }
        }
        return files
    }

    static func parseDiffContent(_ output: String) -> [DiffHunk] {
        let lines = output.components(separatedBy: "\n")
        var hunks: [DiffHunk] = []
        var pendingHunk: DiffHunk?
        var pendingLines: [DiffLine] = []
        var oldLine = 0
        var newLine = 0

        for line in lines {
            if line.hasPrefix("@@ ") {
                if var hunk = pendingHunk {
                    hunk.lines = pendingLines
                    hunks.append(hunk)
                }
                let nsLine = line as NSString
                let nsRange = NSRange(location: 0, length: nsLine.length)
                if let match = hunkRegex.firstMatch(in: line, range: nsRange) {
                    func intAt(_ i: Int, fallback: Int = 1) -> Int {
                        let r = match.range(at: i)
                        guard r.location != NSNotFound else { return fallback }
                        return Int(nsLine.substring(with: r)) ?? fallback
                    }
                    let oldStart = intAt(1)
                    let newStart = intAt(3)
                    pendingHunk = DiffHunk(
                        header: line,
                        oldStart: oldStart,
                        oldCount: intAt(2),
                        newStart: newStart,
                        newCount: intAt(4)
                    )
                    pendingLines = []
                    oldLine = oldStart
                    newLine = newStart
                }
            } else if pendingHunk != nil {
                // hunks.count = index of the current (pending) hunk in the final array
                let hunkIndex = hunks.count
                if line.hasPrefix("+"), !line.hasPrefix("+++") {
                    pendingLines.append(DiffLine(hunkIndex: hunkIndex, index: pendingLines.count, type: .added, content: String(line.dropFirst()), newLineNumber: newLine))
                    newLine += 1
                } else if line.hasPrefix("-"), !line.hasPrefix("---") {
                    pendingLines.append(DiffLine(hunkIndex: hunkIndex, index: pendingLines.count, type: .deleted, content: String(line.dropFirst()), oldLineNumber: oldLine))
                    oldLine += 1
                } else if line.hasPrefix(" ") {
                    pendingLines.append(DiffLine(hunkIndex: hunkIndex, index: pendingLines.count, type: .context, content: String(line.dropFirst()), oldLineNumber: oldLine, newLineNumber: newLine))
                    oldLine += 1
                    newLine += 1
                }
            }
        }
        if var hunk = pendingHunk {
            hunk.lines = pendingLines
            hunks.append(hunk)
        }
        return hunks
    }

    private static func status(from code: String) -> FileStatus? {
        switch code {
        case "M": return .modified
        case "A": return .added
        case "D": return .deleted
        default: return nil
        }
    }
}
