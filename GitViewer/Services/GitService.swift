import Foundation

enum GitError: Error, LocalizedError {
    case notARepository
    case commandFailed(String)
    case parseError(String)
    case outputTooLarge

    var errorDescription: String? {
        switch self {
        case .notARepository: return "Not a git repository"
        case .commandFailed(let msg): return "Git command failed: \(msg)"
        case .parseError(let msg): return "Parse error: \(msg)"
        case .outputTooLarge: return "Command output too large"
        }
    }
}

actor GitService {
    let repositoryURL: URL
    private let gitPath: String

    // Holds flags shared between the continuation body and the onCancel handler.
    // Using a class (reference type) lets both closures capture the same instance
    // via a `let` binding, which Swift 6 concurrency rules allow.
    private final class ProcessState {
        var cancelledByTask = false
        var processLaunched = false
    }

    // Thread-safe lazy resolution via static let (Swift guarantees once-only initialization).
    // Stores Result so a lookup failure is also cached and not retried on every init.
    // Uses FileManager stat checks only — no subprocess — so it never blocks the main thread.
    private static let resolvedGitPath: Result<String, Error> = {
        let candidates = ["/usr/bin/git", "/usr/local/bin/git", "/opt/homebrew/bin/git"]
        if let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return .success(found)
        }
        // Fall back to walking PATH entries directly, avoiding a blocking subprocess.
        let pathEntries = ProcessInfo.processInfo.environment["PATH"]?
            .components(separatedBy: ":") ?? []
        for dir in pathEntries {
            let candidate = (dir as NSString).appendingPathComponent("git")
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return .success(candidate)
            }
        }
        return .failure(GitError.commandFailed("git executable not found. Install Xcode Command Line Tools: xcode-select --install"))
    }()

    init(repositoryURL: URL, gitPath: String? = nil) throws {
        self.repositoryURL = repositoryURL
        self.gitPath = try gitPath ?? GitService.resolvedGitPath.get()
    }

    // MARK: - Core runner

    // Core implementation: launches git, writes optional stdinData, returns raw stdout Data.
    // Throws CancellationError on task cancellation, GitError.commandFailed on non-zero exit.
    // Throws GitError.outputTooLarge if stdout exceeds maxOutputBytes (avoids String conversion).
    private func runCore(_ arguments: [String], stdinData: Data? = nil, maxOutputBytes: Int? = nil) async throws -> Data {
        // Avoid spawning a subprocess when the calling task is already cancelled.
        try Task.checkCancellation()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gitPath)
        process.arguments = arguments
        process.currentDirectoryURL = repositoryURL
        // Force C locale so git output (e.g. %(upstream:track)) is always in English.
        var env = ProcessInfo.processInfo.environment
        env["LC_ALL"] = "C"
        env["GIT_TERMINAL_PROMPT"] = "0"
        // Disables pathspec magic (":glob:", ":top:", etc.) for all invocations, including
        // fetchDiffContent which passes file paths as literal pathspecs. Commands that take no
        // pathspecs (for-each-ref, stash list, rev-parse) are unaffected by this flag.
        env["GIT_LITERAL_PATHSPECS"] = "1"
        process.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        var stdinPipe: Pipe?
        if stdinData != nil {
            let pipe = Pipe()
            process.standardInput = pipe
            stdinPipe = pipe
        }

        // NSLock protects both flags:
        //   cancelledByTask — set by onCancel (arbitrary thread), read by group.notify
        //   processLaunched — set after process.run() succeeds, read by onCancel
        // If the task is already cancelled when withTaskCancellationHandler is entered,
        // onCancel fires synchronously BEFORE the body runs, so process.run() has not
        // been called yet.  Calling terminate() on an unlaunched Process throws
        // NSInvalidArgumentException, so we guard with processLaunched.
        let lock = NSLock()
        let state = ProcessState()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }
                // Mark as launched under lock so a concurrent onCancel sees the flag.
                // Re-check cancelledByTask immediately after setting processLaunched to
                // handle the race where onCancel fired between process.run() and this block.
                lock.lock()
                state.processLaunched = true
                let alreadyCancelled = state.cancelledByTask
                lock.unlock()
                if alreadyCancelled { process.terminate() }

                // Write stdin before reading stdout/stderr so the process can proceed.
                // Path data is small (<4KB), well within the 64KB pipe buffer, so
                // synchronous write will not block.
                if let data = stdinData, let pipe = stdinPipe {
                    pipe.fileHandleForWriting.write(data)
                    pipe.fileHandleForWriting.closeFile()
                }

                // Read stdout and stderr concurrently to prevent pipe buffer deadlock on large output.
                // readDataToEndOfFile() blocks until the write end closes (process exit), so both
                // reads must run in parallel; otherwise the process blocks on a full pipe.
                let group = DispatchGroup()
                let queue = DispatchQueue.global(qos: .userInitiated)
                var stdoutData = Data()
                var stderrData = Data()
                // Set by the stdout reader when maxOutputBytes is exceeded; read in group.notify.
                // Safe without lock: group.notify fires only after all group.leave() calls,
                // establishing happens-before between the writer and this reader.
                var outputLimitExceeded = false

                group.enter()
                queue.async {
                    if let limit = maxOutputBytes {
                        // Stream stdout in chunks to enforce the byte limit without loading
                        // the entire output into memory first (avoids OOM on huge diffs).
                        var acc = Data()
                        var buf = [UInt8](repeating: 0, count: 65536)
                        let fd = stdoutPipe.fileHandleForReading.fileDescriptor
                        outer: while true {
                            let n = Darwin.read(fd, &buf, buf.count)
                            if n < 0 {
                                let e = errno  // capture before any other syscall can overwrite it
                                if e == EINTR { continue }
                                break
                            }
                            if n == 0 { break }
                            acc.append(contentsOf: buf[0..<n])
                            if acc.count > limit {
                                outputLimitExceeded = true
                                process.terminate()
                                // Drain remaining bytes so the process can exit without blocking on a full pipe.
                                // Loop until EOF (d==0) or a non-EINTR error. Non-EINTR errors (e.g. EBADF)
                                // are treated as terminal: the process was already sent SIGTERM and will
                                // exit shortly, causing any blocked writes to receive SIGPIPE.
                                var d: Int
                                repeat { d = Darwin.read(fd, &buf, buf.count) } while d > 0 || (d < 0 && errno == EINTR)
                                break outer
                            }
                        }
                        stdoutData = outputLimitExceeded ? Data() : acc
                    } else {
                        stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    }
                    group.leave()
                }

                group.enter()
                queue.async {
                    // Stream stderr with a 1MB cap to prevent unbounded memory growth from
                    // pathological git output, while always draining to EOF to avoid deadlock.
                    var acc = Data()
                    var buf = [UInt8](repeating: 0, count: 65536)
                    let fd = stderrPipe.fileHandleForReading.fileDescriptor
                    while true {
                        let n = Darwin.read(fd, &buf, buf.count)
                        if n == 0 { break }
                        if n < 0 { if errno == EINTR { continue }; break }
                        if acc.count < 1_048_576 { acc.append(contentsOf: buf[0..<n]) }
                        // Keep reading even past cap to drain the pipe and let the process exit
                    }
                    stderrData = acc
                    group.leave()
                }

                group.notify(queue: queue) {
                    process.waitUntilExit()
                    let stderr = stderrData.utf8OrLatin1

                    lock.lock()
                    let wasCancelled = state.cancelledByTask
                    lock.unlock()

                    if wasCancelled {
                        continuation.resume(throwing: CancellationError())
                    } else if outputLimitExceeded {
                        continuation.resume(throwing: GitError.outputTooLarge)
                    } else if process.terminationStatus == 0 {
                        continuation.resume(returning: stdoutData)
                    } else {
                        let errMsg = stderr.isEmpty ? stdoutData.utf8OrLatin1 : stderr
                        continuation.resume(throwing: GitError.commandFailed(errMsg))
                    }
                }
            }
        } onCancel: {
            lock.lock()
            state.cancelledByTask = true
            let launched = state.processLaunched
            lock.unlock()
            if launched { process.terminate() }
        }
    }

    // Returns git output as a String (UTF-8, falling back to Latin-1).
    func run(_ arguments: [String], stdinData: Data? = nil, maxOutputBytes: Int? = nil) async throws -> String {
        let data = try await runCore(arguments, stdinData: stdinData, maxOutputBytes: maxOutputBytes)
        return data.utf8OrLatin1
    }

    // Escapes a string for use as a POSIX BRE literal.
    // Metacharacters needing escaping: . * [ ^ $ \
    // ] is NOT escaped — outside a bracket expression it is literal, and \] is undefined in POSIX BRE.
    // ( ) { } + ? | must NOT be backslash-escaped (in BRE, \( \) \{ \} are grouping/repetition).
    private func breEscaped(_ s: String) -> String {
        let meta: Set<Character> = [".", "*", "[", "^", "$", "\\"]
        return s.map { meta.contains($0) ? "\\\($0)" : String($0) }.joined()
    }

    private func validateSHA(_ sha: String) throws {
        guard sha.count >= 4, sha.allSatisfy({ $0.isHexDigit }) else {
            throw GitError.parseError("Invalid SHA: \(sha)")
        }
    }

    private func validateRef(_ ref: String) throws {
        guard !ref.isEmpty, !ref.hasPrefix("-"),
              !ref.contains(".."), !ref.contains("@{"),
              !ref.contains(" "), !ref.contains("\0") else {
            throw GitError.parseError("Invalid ref: \(ref)")
        }
    }

    // MARK: - Repository validation

    func validateRepository() async throws {
        // --is-inside-work-tree exits 0 but outputs "false" for bare repos or .git dirs.
        // Verify the output is "true" to reject non-working-tree paths.
        let result = try await run(["rev-parse", "--is-inside-work-tree"])
        guard result.trimmingCharacters(in: .whitespacesAndNewlines) == "true" else {
            throw GitError.notARepository
        }
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
        let format = "%(refname)\t%(refname:short)\t%(objectname:short)\t%(HEAD)\t%(upstream:track)"
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
                // Parse "[ahead N, behind M]" from %(upstream:track)
                let trackInfo = parts.count >= 5 ? parts[4] : ""
                var ahead = 0, behind = 0
                // %(upstream:track) emits "[ahead N]", "[behind M]", "[ahead N, behind M]",
                // "[gone]", or "". Extract numbers by searching only within the "[...]" block
                // to avoid false matches if a branch name contains "ahead" or "behind".
                if let bracketStart = trackInfo.firstIndex(of: "["),
                   let bracketEnd = trackInfo[bracketStart...].firstIndex(of: "]") {
                    let inner = trackInfo[bracketStart...bracketEnd]
                    if let r = inner.range(of: "ahead ") {
                        ahead = Int(inner[r.upperBound...].prefix(while: { $0.isNumber })) ?? 0
                    }
                    if let r = inner.range(of: "behind ") {
                        behind = Int(inner[r.upperBound...].prefix(while: { $0.isNumber })) ?? 0
                    }
                }

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
                // holds just the branch portion.
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
                    isHead: isHead,
                    ahead: ahead,
                    behind: behind
                )
            }
    }

    func listStashes() async throws -> [GitRef] {
        let output = try await run(["stash", "list", "--format=%gd%x00%s"])
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
        try validateRef(ref)
        // Record terminator is \x00\x1E (NUL + RS). Since NUL cannot appear in git log field
        // values, this two-byte sequence is safe even if a commit subject contains bare \x1E.
        // Body (%b) is omitted: loaded lazily via fetchCommitBody when a commit is selected.
        let format = "%H%x00%P%x00%an%x00%ae%x00%ai%x00%cn%x00%ce%x00%ci%x00%s%x00%D%x00%x1E"
        return try await run([
            "log", ref,
            "--format=\(format)",
            "--decorate=full",
            "-n", "\(limit)",
            "--skip", "\(offset)",
            "--"
        ], maxOutputBytes: 20_971_520)
    }

    func fetchLogSearch(ref: String, grep: String, limit: Int = 500) async throws -> String {
        try validateRef(ref)
        let format = "%H%x00%P%x00%an%x00%ae%x00%ai%x00%cn%x00%ce%x00%ci%x00%s%x00%D%x00%x1E"
        return try await run([
            "log", ref,
            "--format=\(format)",
            "--decorate=full",
            "--grep", grep,
            "--fixed-strings", "-i",
            "-n", "\(limit)",
            "--"
        ], maxOutputBytes: 20_971_520)
    }

    func fetchLogSearchByAuthor(ref: String, author: String, limit: Int = 500) async throws -> String {
        try validateRef(ref)
        let format = "%H%x00%P%x00%an%x00%ae%x00%ai%x00%cn%x00%ce%x00%ci%x00%s%x00%D%x00%x1E"
        // --author interprets its argument as a POSIX BRE. Escape BRE metacharacters so
        // the query is treated as a literal string. NSRegularExpression.escapedPattern is
        // wrong here: it escapes ( ) { } + ? | with backslash, but in BRE those escape
        // sequences activate grouping/repetition syntax rather than producing literals.
        let escapedAuthor = breEscaped(author)
        return try await run([
            "log", ref,
            "--format=\(format)",
            "--decorate=full",
            "--author", escapedAuthor,
            "-i",
            "-n", "\(limit)",
            "--"
        ], maxOutputBytes: 20_971_520)
    }

    // Returns the commit body (everything after the first blank line), trimmed.
    // Returns empty string if the commit has no body.
    func fetchCommitBody(sha: String) async throws -> String {
        try validateSHA(sha)
        let data = try await runCore(["log", "-1", "--format=%b", sha, "--"], maxOutputBytes: 1_048_576)
        return data.utf8OrLatin1.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Working Tree

    func fetchWorkingTreeStatus() async throws -> Data {
        return try await runCore(
            ["status", "--porcelain=v1", "-z", "--no-renames", "--untracked-files=all"],
            maxOutputBytes: 5_242_880
        )
    }

    func fetchStagedDiff(rawPath: Data) async throws -> String {
        let pathStr = try validateWorkingTreePath(rawPath)
        let data = try await runCore(
            ["diff", "--cached", "--no-ext-diff", "--no-textconv", "--", pathStr],
            maxOutputBytes: 5_000_000
        )
        return data.utf8OrLatin1
    }

    // Reads an untracked (not in index) file from disk and returns its content.
    // Throws GitError.outputTooLarge for files > 5MB, GitError.commandFailed for binaries.
    // I/O is offloaded to a global queue to avoid blocking the actor thread.
    func fetchUntrackedContent(rawPath: Data) async throws -> String {
        try Task.checkCancellation()
        let pathStr = try validateWorkingTreePath(rawPath)
        let fileURL = repositoryURL.appendingPathComponent(pathStr)
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                    if let size = attrs[.size] as? Int, size > 5_000_000 {
                        continuation.resume(throwing: GitError.outputTooLarge)
                        return
                    }
                    let data = try Data(contentsOf: fileURL)
                    guard !data.contains(0) else {
                        continuation.resume(throwing: GitError.commandFailed("binary file"))
                        return
                    }
                    continuation.resume(returning: data.utf8OrLatin1)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchUnstagedDiff(rawPath: Data) async throws -> String {
        let pathStr = try validateWorkingTreePath(rawPath)
        let data = try await runCore(
            ["diff", "--no-ext-diff", "--no-textconv", "--", pathStr],
            maxOutputBytes: 5_000_000
        )
        return data.utf8OrLatin1
    }

    private func validateWorkingTreePath(_ rawPath: Data) throws -> String {
        let pathStr = rawPath.utf8OrLatin1
        guard !rawPath.contains(0),
              !pathStr.isEmpty,
              !pathStr.hasPrefix("/"),
              !pathStr.components(separatedBy: "/").contains("..") else {
            throw GitError.parseError("Invalid file path")
        }
        return pathStr
    }

    // MARK: - Diff

    // Returns raw Data to preserve non-UTF-8 path bytes for use in fetchDiffContent.
    func fetchDiff(commit sha: String) async throws -> Data {
        try validateSHA(sha)
        // -z: NUL-separate paths so filenames with tabs/newlines parse correctly.
        // --no-ext-diff --no-textconv: prevent untrusted repo configs from running arbitrary external helpers.
        // --diff-merges=first-parent: produce unified diff for merge commits (combined diff @@@ breaks parser).
        return try await runCore(["show", sha, "--diff-merges=first-parent",
                                  "--no-ext-diff", "--no-textconv",
                                  "--format=", "--name-status", "-z"],
                                 maxOutputBytes: 5_242_880)
    }

    // Validates a raw path Data from git output: no NUL, non-empty, no absolute or traversal path.
    // Returns the decoded path string on success.
    private func validateBlobPath(_ rawPath: Data) throws -> String {
        let pathStr = rawPath.utf8OrLatin1
        guard !rawPath.contains(0),
              !pathStr.isEmpty,
              !pathStr.hasPrefix("/"),
              !pathStr.components(separatedBy: "/").contains("..") else {
            throw GitError.parseError("Invalid file path")
        }
        return pathStr
    }

    // Returns the staged blob for a working tree file (git show :<path>).
    func fetchStagedFileBlob(rawPath: Data) async throws -> Data {
        let pathStr = try validateBlobPath(rawPath)
        return try await runCore(["show", ":\(pathStr)"], maxOutputBytes: 52_428_800)
    }

    // Returns the current on-disk content for a working tree file.
    // Enforces the same 50MB limit as fetchFileBlob to prevent OOM on large files.
    func fetchWorkingTreeFileBlob(rawPath: Data) async throws -> Data {
        try Task.checkCancellation()
        let pathStr = try validateBlobPath(rawPath)
        let fileURL = repositoryURL.appendingPathComponent(pathStr)
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                    if let size = attrs[.size] as? Int, size > 52_428_800 {
                        continuation.resume(throwing: GitError.outputTooLarge)
                        return
                    }
                    let data = try Data(contentsOf: fileURL)
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // Returns the raw file content at the given commit (git show <sha>:<path>).
    // Used for binary file preview; returns Data so callers can interpret as image or save to disk.
    func fetchFileBlob(commit sha: String, rawPath: Data) async throws -> Data {
        try validateSHA(sha)
        let pathStr = try validateBlobPath(rawPath)
        // <sha>:<path> (colon syntax) retrieves the blob at that exact tree entry.
        // maxOutputBytes: 50MB — large enough for typical images, prevents OOM on oversized blobs.
        return try await runCore(["show", "\(sha):\(pathStr)"], maxOutputBytes: 52_428_800)
    }

    // Accepts raw path bytes (from DiffFile.rawNewPath) to handle non-UTF-8 filenames.
    // Path is passed via argv as `-- <path>`; GIT_LITERAL_PATHSPECS=1 prevents ':' magic.
    func fetchDiffContent(commit sha: String, rawPath: Data) async throws -> String {
        try validateSHA(sha)
        // Defense-in-depth: path comes from git's own output so absolute paths and ".."
        // components should never appear in legitimate repos, but guard anyway.
        // rawPath is checked for NUL (would split the argv entry); pathStr is checked for
        // traversal sequences (the decoded string is what git receives as the pathspec).
        let pathStr = try validateBlobPath(rawPath)
        // --format= suppresses the commit header so only the diff body is returned.
        // --diff-merges=first-parent: unified diff for merge commits (combined diff @@@ breaks parser).
        // GIT_LITERAL_PATHSPECS=1 (set in runCore env) prevents ':'-prefixed pathspec magic.
        // `-- <path>` is preferred over --pathspec-from-file because that flag is not supported
        // by Apple's bundled git (Apple Git-155) despite its version number indicating otherwise.
        let data = try await runCore(
            ["show", sha,
             "--diff-merges=first-parent",
             "--no-ext-diff", "--no-textconv", "--format=",
             "--", pathStr],
            maxOutputBytes: 5_000_000
        )
        return data.utf8OrLatin1
    }
}
