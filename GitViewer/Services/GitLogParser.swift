import Foundation

struct GitLogParser {
    // git log format fields (NUL-separated, terminated by NUL+RS \x00\x1E):
    // 0:SHA 1:parents 2:authorName 3:authorEmail 4:authorDate
    // 5:committerName 6:committerEmail 7:committerDate 8:subject 9:decoration(%D)
    // Record terminator is \x00\x1E so a bare \x1E in a commit subject is safe.
    // Body (%b) is intentionally excluded — loaded lazily via fetchCommitBody.

    static func parse(_ output: String) -> [Commit] {
        // One formatter per parse call — avoids shared mutable state while still
        // reusing the same instance across all records in this batch.
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        // split returns [Substring] — views into output, no copy per record.
        var result: [Commit] = []
        for record in output.split(separator: "\0\u{1E}") {
            if Task.isCancelled { break }
            if let c = parseBlock(record, dateFormatter: df) { result.append(c) }
        }
        return result
    }

    // Takes Substring to avoid a per-record String copy; fields are split as Substrings too.
    private static func parseBlock(_ block: Substring, dateFormatter: DateFormatter) -> Commit? {
        // split(omittingEmptySubsequences:false) returns [Substring] — no field string copies.
        let parts = block.split(separator: "\0", omittingEmptySubsequences: false)
        // Minimum 10 tokens: fields 0-8 (sha…subject) + decoration as parts[9].
        guard parts.count >= 10 else { return nil }

        let sha = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard sha.count == 40, sha.allSatisfy({ $0.isHexDigit }) else { return nil }

        let parentSHAs = parts[1].split(separator: " ").map(String.init).filter { !$0.isEmpty }
        let authorDate = dateFormatter.date(from: parts[4].trimmingCharacters(in: .whitespacesAndNewlines)) ?? Date.distantPast
        let committerDate = dateFormatter.date(from: parts[7].trimmingCharacters(in: .whitespacesAndNewlines)) ?? Date.distantPast

        return Commit(
            id: sha,
            shortSHA: String(sha.prefix(7)),
            parentSHAs: parentSHAs,
            subject: String(parts[8]),
            message: String(parts[8]),
            authorName: String(parts[2]),
            authorEmail: String(parts[3]),
            authorDate: authorDate,
            committerName: String(parts[5]),
            committerEmail: String(parts[6]),
            committerDate: committerDate,
            refs: parseDecoration(String(parts[9]))
        )
    }

    // Parses %D decoration produced by `git log --decorate=full`.
    // Full ref names (refs/heads/*, refs/remotes/*, refs/tags/*) allow unambiguous
    // classification of local branches that contain slashes (e.g. feature/foo).
    private static func parseDecoration(_ decoration: String) -> [GitRef] {
        let trimmed = decoration.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        return trimmed.components(separatedBy: ", ").compactMap { item -> GitRef? in
            if item.hasPrefix("HEAD -> ") {
                let fullRef = String(item.dropFirst(8))
                let shortName = fullRef.hasPrefix("refs/heads/")
                    ? String(fullRef.dropFirst("refs/heads/".count))
                    : fullRef
                return GitRef(name: fullRef, shortName: shortName, sha: "", refType: .localBranch, isHead: true)
            } else if item == "HEAD" {
                return nil
            } else if item.hasPrefix("tag: ") {
                let fullRef = String(item.dropFirst(5))
                let shortName = fullRef.hasPrefix("refs/tags/")
                    ? String(fullRef.dropFirst("refs/tags/".count))
                    : fullRef
                return GitRef(name: fullRef, shortName: shortName, sha: "", refType: .tag)
            }
            // For remote/local branches, take only the ref name before any " -> " symbolic pointer.
            let refOnly = item.components(separatedBy: " -> ").first ?? item
            if refOnly.hasPrefix("refs/remotes/") {
                // Skip symbolic remote HEADs (e.g. refs/remotes/origin/HEAD).
                guard !refOnly.hasSuffix("/HEAD") else { return nil }
                let rest = String(refOnly.dropFirst("refs/remotes/".count))
                guard let slashIdx = rest.firstIndex(of: "/") else { return nil }
                let remote = String(rest[rest.startIndex..<slashIdx])
                let branch = String(rest[rest.index(after: slashIdx)...])
                return GitRef(name: refOnly, shortName: branch, sha: "", refType: .remoteBranch(remote: remote))
            } else if refOnly.hasPrefix("refs/heads/") {
                let shortName = String(refOnly.dropFirst("refs/heads/".count))
                return GitRef(name: refOnly, shortName: shortName, sha: "", refType: .localBranch)
            } else {
                return nil
            }
        }
    }
}
