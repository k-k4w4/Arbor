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

    // Thread-safe lazy resolution via static let (Swift guarantees once-only initialization).
    // Stores Result so a lookup failure is also cached and not retried on every init.
    private static let resolvedGitPath: Result<String, Error> = {
        let candidates = ["/usr/bin/git", "/usr/local/bin/git", "/opt/homebrew/bin/git"]
        if let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return .success(found)
        }
        // Fall back to searching PATH via `which git`
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        which.arguments = ["git"]
        let pipe = Pipe()
        which.standardOutput = pipe
        which.standardError = Pipe()
        do {
            try which.run()
        } catch {
            return .failure(GitError.commandFailed("git executable not found. Install Xcode Command Line Tools: xcode-select --install"))
        }
        which.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) else {
            return .failure(GitError.commandFailed("git executable not found. Install Xcode Command Line Tools: xcode-select --install"))
        }
        return .success(path)
    }()

    init(repositoryURL: URL, gitPath: String? = nil) throws {
        self.repositoryURL = repositoryURL
        self.gitPath = try gitPath ?? GitService.resolvedGitPath.get()
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

        // NSLock protects both flags:
        //   cancelledByTask — set by onCancel (arbitrary thread), read by group.notify
        //   processLaunched — set after process.run() succeeds, read by onCancel
        // If the task is already cancelled when withTaskCancellationHandler is entered,
        // onCancel fires synchronously BEFORE the body runs, so process.run() has not
        // been called yet.  Calling terminate() on an unlaunched Process throws
        // NSInvalidArgumentException, so we guard with processLaunched.
        let lock = NSLock()
        var cancelledByTask = false
        var processLaunched = false
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }
                // Mark as launched under lock so a concurrent onCancel sees the flag.
                lock.lock()
                processLaunched = true
                lock.unlock()

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
                    // Fall back to Latin-1 so non-UTF-8 bytes (e.g. in filenames or
                    // binary patches) don't silently collapse the entire output to "".
                    let output = String(data: stdoutData, encoding: .utf8)
                        ?? String(data: stdoutData, encoding: .isoLatin1) ?? ""
                    let stderr = String(data: stderrData, encoding: .utf8)
                        ?? String(data: stderrData, encoding: .isoLatin1) ?? ""

                    lock.lock()
                    let wasCancelled = cancelledByTask
                    lock.unlock()

                    if wasCancelled {
                        continuation.resume(throwing: CancellationError())
                    } else if process.terminationStatus == 0 {
                        continuation.resume(returning: output)
                    } else {
                        continuation.resume(throwing: GitError.commandFailed(stderr.isEmpty ? output : stderr))
                    }
                }
            }
        } onCancel: {
            lock.lock()
            cancelledByTask = true
            let launched = processLaunched
            lock.unlock()
            if launched { process.terminate() }
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
        // Tab as field separator: safe because git prohibits control chars (< 0x20) in ref names.
        // for-each-ref uses a different format parser from git-log and does not interpret %xNN.
        let format = "%(refname)\t%(refname:short)\t%(objectname:short)\t%(HEAD)"
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
                let parts = line.components(separatedBy: "\t")
                guard parts.count >= 4 else { return nil }
                let fullRefname = parts[0]
                let shortName = parts[1]
                let sha = parts[2]
                let isHead = parts[3] == "*"

                // refs/remotes/*/HEAD is a symbolic tracking pointer, not a real branch.
                if fullRefname.hasPrefix("refs/remotes/") && fullRefname.hasSuffix("/HEAD") {
                    return nil
                }

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

                // For remote branches strip the "remote/" prefix so shortName
                // holds just the branch portion; gitRef reassembles "remote/branch".
                // For local branches and tags keep the full %(refname:short).
                let displayName: String
                if case .remoteBranch(let remote) = refType {
                    let prefix = remote + "/"
                    displayName = shortName.hasPrefix(prefix)
                        ? String(shortName.dropFirst(prefix.count))
                        : shortName
                } else {
                    displayName = shortName
                }
                return GitRef(
                    name: fullRefname,
                    shortName: displayName,
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
        guard !ref.isEmpty, !ref.hasPrefix("-") else {
            throw GitError.parseError("Invalid ref: \(ref)")
        }
        // Use %x1E (ASCII Record Separator) as commit delimiter — safe against any commit message content
        let format = "%H%x00%P%x00%an%x00%ae%x00%ai%x00%cn%x00%ci%x00%s%x00%b%x00%D%x1E"
        return try await run([
            "log", ref,
            "--format=\(format)",
            "-n", "\(limit)",
            "--skip", "\(offset)"
        ])
    }

    // MARK: - Diff

    func fetchDiff(commit sha: String) async throws -> String {
        try validateSHA(sha)
        // -z: NUL-separate paths so filenames with tabs/newlines parse correctly.
        // --no-ext-diff --no-textconv: prevent untrusted repo configs from running
        // arbitrary external helpers.
        return try await run(["show", sha, "--no-ext-diff", "--no-textconv",
                              "--format=", "--name-status", "-z"])
    }

    func fetchDiffContent(commit sha: String, file: String) async throws -> String {
        try validateSHA(sha)
        // Reject control characters and absolute paths; check ".." as path component
        // to avoid blocking legitimate filenames like "..foo".
        guard !file.contains("\0"), !file.contains("\n"), !file.contains("\r"),
              !file.hasPrefix("/"),
              !file.components(separatedBy: "/").contains("..") else {
            throw GitError.parseError("Invalid file path: \(file)")
        }
        return try await run(["show", sha, "--no-ext-diff", "--no-textconv", "--", file])
    }
}
