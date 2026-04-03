import Foundation

struct GitDiffParser {
    // Fixed pattern: always valid, force-unwrap is safe here
    private static let hunkRegex = try! NSRegularExpression(
        pattern: #"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@"#
    )

    // Parses `git show --name-status -z` output where fields are NUL-separated.
    // Format: STATUS\0PATH\0 or STATUS\0OLD\0NEW\0 for renames/copies.
    // NUL separation avoids misparse of filenames containing tabs or newlines.
    // Accepts raw Data to preserve original path bytes (non-UTF-8 filenames round-trip
    // correctly when later passed to git via stdin in fetchDiffContent).
    static func parseNameStatus(_ output: Data) -> [DiffFile] {
        var files: [DiffFile] = []
        var tokens = splitByNUL(output)
        // Trailing NUL produces an empty last token; strip exactly empty Data.
        if tokens.last == Data() {
            tokens.removeLast()
        }
        var i = 0
        while i < tokens.count {
            if Task.isCancelled { break }
            let code = decodeToken(tokens[i]).trimmingCharacters(in: .whitespacesAndNewlines)
            i += 1
            guard !code.isEmpty else { continue }

            if code.hasPrefix("R") || code.hasPrefix("C") {
                guard i + 1 < tokens.count else { break }
                let oldData = tokens[i]; let newData = tokens[i + 1]
                i += 2
                files.append(DiffFile(
                    status: code.hasPrefix("R") ? .renamed : .copied,
                    oldPath: decodeToken(oldData), newPath: decodeToken(newData),
                    rawOldPath: oldData, rawNewPath: newData))
            } else if let s = status(from: code) {
                guard i < tokens.count else { break }
                let pathData = tokens[i]
                i += 1
                files.append(DiffFile(status: s, newPath: decodeToken(pathData),
                                      rawNewPath: pathData))
            }
        }
        return files
    }

    // String overload for backwards compatibility (test helpers pass literal strings).
    static func parseNameStatus(_ output: String) -> [DiffFile] {
        parseNameStatus(output.data(using: .utf8) ?? Data())
    }

    private static func splitByNUL(_ data: Data) -> [Data] {
        var result: [Data] = []
        var start = data.startIndex
        while let nulIdx = data[start...].firstIndex(of: 0) {
            result.append(data[start..<nulIdx])
            start = data.index(after: nulIdx)
        }
        // Append the remainder only if non-empty; a trailing NUL leaves start == endIndex.
        if start < data.endIndex {
            result.append(data[start...])
        }
        return result
    }

    private static func decodeToken(_ data: Data) -> String {
        String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1) ?? ""
    }

    static func parseDiffContent(_ output: String) -> [DiffHunk] {
        var hunks: [DiffHunk] = []
        var pendingHunk: DiffHunk?
        var pendingLines: [DiffLine] = []
        var oldLine = 0
        var newLine = 0

        // split(whereSeparator:) returns [Substring] — no per-line String copies.
        // isNewline handles LF, CR, and CRLF. Swift's Character treats \r\n as a single
        // grapheme cluster, so split(separator: "\n") would not split at \r\n at all.
        for line in output.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            if Task.isCancelled { break }
            if line.hasPrefix("@@ ") {
                if var hunk = pendingHunk {
                    hunk.lines = pendingLines
                    hunks.append(hunk)
                }
                let lineStr = String(line)
                let nsLine = lineStr as NSString
                let nsRange = NSRange(location: 0, length: nsLine.length)
                if let match = hunkRegex.firstMatch(in: lineStr, range: nsRange) {
                    func intAt(_ i: Int, fallback: Int = 1) -> Int {
                        let r = match.range(at: i)
                        guard r.location != NSNotFound else { return fallback }
                        return Int(nsLine.substring(with: r)) ?? fallback
                    }
                    let oldStart = intAt(1)
                    let newStart = intAt(3)
                    pendingHunk = DiffHunk(
                        header: lineStr,
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
                if line == #"\ No newline at end of file"# {
                    pendingLines.append(DiffLine(hunkIndex: hunkIndex, index: pendingLines.count, type: .noNewline, content: String(line)))
                } else if line.hasPrefix("+"), !line.hasPrefix("+++") {
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
        // R/C codes are already consumed by the hasPrefix check above.
        // Two-character conflict codes (AA, AU, UA, UU, DD, DU, UD) consist of A/D/U combinations
        // and represent unresolved merge states. Unknown two-char codes (not A/D/U) fall through
        // to `default: return nil` so they are skipped rather than misclassified.
        if code.count >= 2 {
            let conflictChars: Set<Character> = ["A", "D", "U"]
            if code.allSatisfy({ conflictChars.contains($0) }) { return .unmerged }
            return nil
        }
        switch code.first {
        case "M": return .modified
        case "A": return .added
        case "D": return .deleted
        case "T": return .typeChanged
        case "U": return .unmerged
        default: return nil
        }
    }
}
