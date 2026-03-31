import Foundation

enum GitError: Error, LocalizedError {
    case notARepository
    case commandFailed(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .notARepository: return "Not a git repository"
        case .commandFailed(let msg): return "Git command failed: \(msg)"
        case .parseError(let msg): return "Parse error: \(msg)"
        }
    }
}

actor GitService {
    let repositoryURL: URL
    private let gitPath: String

    init(repositoryURL: URL, gitPath: String = "/usr/bin/git") {
        self.repositoryURL = repositoryURL
        self.gitPath = gitPath
    }

    // MARK: - Core runner

    func run(_ arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gitPath)
        process.arguments = arguments
        process.currentDirectoryURL = repositoryURL

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                // Read stdout and stderr concurrently to prevent pipe buffer deadlock on large output.
                // readDataToEndOfFile() blocks until the write end closes (process exit), so both
                // reads must run in parallel; otherwise the process blocks on a full pipe.
                let group = DispatchGroup()
                let queue = DispatchQueue.global(qos: .userInitiated)
                var stdoutData = Data()
                var stderrData = Data()

                group.enter()
                queue.async {
                    stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    group.leave()
                }

                group.enter()
                queue.async {
                    stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    group.leave()
                }

                group.notify(queue: queue) {
                    process.waitUntilExit()
                    let output = String(data: stdoutData, encoding: .utf8) ?? ""
                    let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                    if process.terminationStatus == 0 {
                        continuation.resume(returning: output)
                    } else {
                        continuation.resume(throwing: GitError.commandFailed(stderr.isEmpty ? output : stderr))
                    }
                }
            }
        } onCancel: {
            process.terminate()
        }
    }

    private func validateSHA(_ sha: String) throws {
        guard sha.count >= 4, sha.allSatisfy({ $0.isHexDigit }) else {
            throw GitError.parseError("Invalid SHA: \(sha)")
        }
    }

    // MARK: - Repository validation

    func validateRepository() async throws {
        _ = try await run(["rev-parse", "--is-inside-work-tree"])
    }

    // MARK: - HEAD branch

    func fetchHeadBranch() async throws -> String {
        let output = try await run(["rev-parse", "--abbrev-ref", "HEAD"])
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Refs

    func listBranches() async throws -> [GitRef] {
        // Use %x00 so NUL is in the output, not in the format argument itself
        let format = "%(refname)%x00%(refname:short)%x00%(objectname:short)%x00%(HEAD)"
        let output = try await run([
            "for-each-ref",
            "--format=\(format)",
            "refs/heads",
            "refs/remotes",
            "refs/tags"
        ])

        return output
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { line -> GitRef? in
                let parts = line.components(separatedBy: "\0")
                guard parts.count >= 4 else { return nil }
                let fullRefname = parts[0]
                let shortName = parts[1]
                let sha = parts[2]
                let isHead = parts[3] == "*"

                let refType: RefType
                if fullRefname.hasPrefix("refs/heads/") {
                    refType = .localBranch
                } else if fullRefname.hasPrefix("refs/remotes/") {
                    let remote = fullRefname
                        .dropFirst("refs/remotes/".count)
                        .split(separator: "/").first
                        .map(String.init) ?? "origin"
                    refType = .remoteBranch(remote: remote)
                } else if fullRefname.hasPrefix("refs/tags/") {
                    refType = .tag
                } else {
                    return nil
                }

                return GitRef(
                    name: fullRefname,
                    shortName: shortName.components(separatedBy: "/").last ?? shortName,
                    sha: sha,
                    refType: refType,
                    isHead: isHead
                )
            }
    }

    func listStashes() async throws -> [GitRef] {
        let output: String
        do {
            output = try await run(["stash", "list", "--format=%gd%x00%s"])
        } catch {
            return []
        }

        return output
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .enumerated()
            .compactMap { index, line -> GitRef? in
                let parts = line.components(separatedBy: "\0")
                guard parts.count >= 2 else { return nil }
                let refName = parts[0]
                let message = parts[1]
                return GitRef(
                    name: refName,
                    shortName: message,
                    sha: "",
                    refType: .stash(index: index)
                )
            }
    }

    // MARK: - Log

    func fetchLog(ref: String = "HEAD", limit: Int = 200, offset: Int = 0) async throws -> String {
        let format = "%H%x00%P%x00%an%x00%ae%x00%ai%x00%cn%x00%ci%x00%s%x00%b%x00%D%x00---COMMIT_END---"
        return try await run([
            "log", ref,
            "--format=\(format)",
            "-n", "\(limit)",
            "--skip", "\(offset)"
        ])
    }

    func fetchAllLog(limit: Int = 1000) async throws -> String {
        let format = "%H%x00%P%x00%an%x00%ae%x00%ai%x00%cn%x00%ci%x00%s%x00%b%x00%D%x00---COMMIT_END---"
        return try await run([
            "log", "--all",
            "--format=\(format)",
            "-n", "\(limit)"
        ])
    }

    // MARK: - Diff

    func fetchDiff(commit sha: String) async throws -> String {
        try validateSHA(sha)
        return try await run(["show", sha, "--format=", "--name-status"])
    }

    func fetchDiffContent(commit sha: String, file: String) async throws -> String {
        try validateSHA(sha)
        return try await run(["show", sha, "--", file])
    }
}
