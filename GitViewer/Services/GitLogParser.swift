import Foundation

struct GitLogParser {
    // git log format fields (NUL-separated, terminated by ---COMMIT_END---):
    // 0:SHA 1:parents 2:authorName 3:authorEmail 4:authorDate
    // 5:committerName 6:committerDate 7:subject 8:body 9:decoration(%D)
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return f
    }()

    static func parse(_ output: String) -> [Commit] {
        output
            .components(separatedBy: "---COMMIT_END---")
            .compactMap { parseBlock($0) }
    }

    private static func parseBlock(_ block: String) -> Commit? {
        let parts = block.components(separatedBy: "\0")
        guard parts.count >= 9 else { return nil }

        let sha = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard sha.count == 40, sha.allSatisfy({ $0.isHexDigit }) else { return nil }

        let parentSHAs = parts[1].split(separator: " ").map(String.init).filter { !$0.isEmpty }
        let authorDate = dateFormatter.date(from: parts[4].trimmingCharacters(in: .whitespacesAndNewlines)) ?? Date()
        let committerDate = dateFormatter.date(from: parts[6].trimmingCharacters(in: .whitespacesAndNewlines)) ?? Date()
        let body = parts[8].trimmingCharacters(in: .whitespacesAndNewlines)
        let decoration = parts.count > 9 ? parts[9] : ""

        return Commit(
            id: sha,
            shortSHA: String(sha.prefix(7)),
            parentSHAs: parentSHAs,
            subject: parts[7],
            message: body.isEmpty ? parts[7] : body,
            authorName: parts[2],
            authorEmail: parts[3],
            authorDate: authorDate,
            committerName: parts[5],
            committerDate: committerDate,
            refs: parseDecoration(decoration)
        )
    }

    private static func parseDecoration(_ decoration: String) -> [GitRef] {
        let trimmed = decoration.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        return trimmed.components(separatedBy: ", ").compactMap { item -> GitRef? in
            if item.hasPrefix("HEAD -> ") {
                let branch = String(item.dropFirst(8))
                return GitRef(name: "refs/heads/\(branch)", shortName: branch, sha: "", refType: .localBranch, isHead: true)
            } else if item == "HEAD" {
                return nil
            } else if item.hasPrefix("tag: ") {
                let tag = String(item.dropFirst(5))
                return GitRef(name: "refs/tags/\(tag)", shortName: tag, sha: "", refType: .tag)
            } else if let slashRange = item.range(of: "/") {
                let remote = String(item[item.startIndex..<slashRange.lowerBound])
                let branch = String(item[slashRange.upperBound...])
                return GitRef(name: "refs/remotes/\(item)", shortName: branch, sha: "", refType: .remoteBranch(remote: remote))
            } else {
                return GitRef(name: "refs/heads/\(item)", shortName: item, sha: "", refType: .localBranch)
            }
        }
    }
}
