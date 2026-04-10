import Foundation
import Observation

enum SearchMode: Int, CaseIterable {
    case message
    case filePath
}

@MainActor
@Observable
final class CommitListViewModel {
    var commits: [Commit] = []
    var filteredCommits: [Commit] = []
    var selectedCommit: Commit?
    var searchQuery: String = ""
    var searchMode: SearchMode = .message
    var isLoading: Bool = false
    var hasMore: Bool = true
    var errorMessage: String?

    // Empty string ensures the initial `ref.gitRef != currentRef` guard in
    // CommitListView's .task(id:) always passes on a fresh VM, including
    // detached HEAD repos where gitRef == "HEAD" would otherwise match the
    // old "HEAD" default and silently skip the initial load.
    private(set) var currentRef: String = ""
    private var fetchOffset: Int = 0
    private let pageSize = 200
    private var loadTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var workingTreeTask: Task<Void, Never>?
    private var workingTreeGeneration = 0
    private var loadingGeneration = 0
    private var gitService: GitService?
    private var graphActiveLanes: [String?] = []  // incremental graph state across pages

    func cancelAll() {
        loadTask?.cancel()
        searchTask?.cancel()
        workingTreeTask?.cancel()
    }

    func loadInitial(ref: String, service: GitService) {
        loadTask?.cancel()
        searchTask?.cancel()
        workingTreeTask?.cancel()
        loadingGeneration += 1
        let loadingGen = loadingGeneration
        commits = []
        filteredCommits = []
        fetchOffset = 0
        hasMore = true
        isLoading = true
        selectedCommit = nil
        errorMessage = nil
        graphActiveLanes = []
        currentRef = ref
        gitService = service
        searchQuery = ""
        searchMode = .message
        workingTreeGeneration += 1
        let wtGen = workingTreeGeneration
        loadTask = Task { [weak self] in await self?.fetchPage(generation: loadingGen) }
        workingTreeTask = Task { [weak self] in await self?.fetchWorkingTree(service: service, generation: wtGen) }
    }

    func loadMore() {
        guard !isLoading, hasMore, gitService != nil, searchQuery.isEmpty else { return }
        loadTask?.cancel()
        loadingGeneration += 1
        let loadingGen = loadingGeneration
        errorMessage = nil
        isLoading = true
        loadTask = Task { [weak self] in await self?.fetchPage(generation: loadingGen) }
    }

    func searchModeChanged() {
        guard !searchQuery.isEmpty, !looksLikeSHA(searchQuery) else { return }
        searchQueryChanged(searchQuery)
    }

    // Called from view's onChange(of: searchQuery) — fires only on actual value changes,
    // not on spurious focus events that macOS searchable may emit.
    func searchQueryChanged(_ query: String) {
        searchTask?.cancel()
        if query.isEmpty {
            if !commits.isEmpty {
                filteredCommits = commits
                // A search result may not exist in the local page cache (commits).
                // Reset selection to the first available commit if the selected one is missing.
                let stillPresent = selectedCommit.map { c in filteredCommits.contains { $0.id == c.id } } ?? true
                if !stillPresent { selectedCommit = filteredCommits.first }
                isLoading = false
            } else if gitService != nil {
                // loadTask was cancelled while typing a query before the first page loaded.
                // Restart the fetch so the list doesn't stay empty with isLoading=true.
                loadTask?.cancel()
                loadingGeneration += 1
                let loadingGen = loadingGeneration
                isLoading = true
                loadTask = Task { [weak self] in await self?.fetchPage(generation: loadingGen) }
            }
        } else if looksLikeSHA(query) {
            jumpToSHA(query)
        } else {
            loadTask?.cancel()
            // Suppress working tree sentinel during search (search results come from git log, not working tree).
            filteredCommits = commits.filter { !$0.isWorkingTreeSentinel }
            selectedCommit = nil
            errorMessage = nil
            isLoading = true
            loadingGeneration += 1
            let loadingGen = loadingGeneration
            searchTask = Task { [weak self] in
                do { try await Task.sleep(nanoseconds: 300_000_000) } catch {
                    return  // Cancelled; caller already manages isLoading
                }
                await self?.performGlobalSearch(query: query, generation: loadingGen)
            }
        }
    }

    private func looksLikeSHA(_ s: String) -> Bool {
        s.count >= 7 && s.count <= 40 && s.allSatisfy { $0.isHexDigit }
    }

    // Public: direct jump without touching searchQuery (used by parent commit links).
    // Does NOT go through searchQueryChanged/onChange to avoid double-firing.
    func jumpToCommit(sha: String) {
        loadTask?.cancel()
        searchTask?.cancel()
        filteredCommits = []
        selectedCommit = nil
        errorMessage = nil
        isLoading = true
        loadingGeneration += 1
        let loadingGen = loadingGeneration
        searchTask = Task { [weak self] in await self?.fetchAndSelectCommit(sha: sha, generation: loadingGen) }
    }

    private func fetchAndSelectCommit(sha: String, generation: Int) async {
        guard let service = gitService else { return }
        defer {
            if loadingGeneration == generation, isLoading {
                isLoading = false
            }
        }
        do {
            let output = try await service.fetchCommitBySHA(sha)
            guard !Task.isCancelled else { return }
            let (found, _) = await parseAndCountLog(output)
            guard !Task.isCancelled else { return }
            filteredCommits = found
            selectedCommit = found.first
        } catch is CancellationError {
        } catch {
            filteredCommits = []
        }
    }

    private func jumpToSHA(_ sha: String) {
        loadTask?.cancel()
        filteredCommits = []
        selectedCommit = nil
        errorMessage = nil
        isLoading = true
        loadingGeneration += 1
        let loadingGen = loadingGeneration
        searchTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 300_000_000) } catch { return }
            await self?.performSHALookup(sha: sha, generation: loadingGen)
        }
    }

    private func performSHALookup(sha: String, generation: Int) async {
        guard let service = gitService else { return }
        defer {
            if loadingGeneration == generation, isLoading {
                isLoading = false
            }
        }
        do {
            let output = try await service.fetchCommitBySHA(sha)
            guard searchQuery == sha else { return }
            let (found, _) = await parseAndCountLog(output)
            guard searchQuery == sha else { return }
            filteredCommits = found
            selectedCommit = found.first
        } catch is CancellationError {
        } catch {
            guard searchQuery == sha else { return }
            // Don't show git error text; let the empty-state view handle "no results".
            filteredCommits = []
        }
    }

    // MARK: - Working Tree

    private func fetchWorkingTree(service: GitService, generation: Int) async {
        do {
            let data = try await service.fetchWorkingTreeStatus()
            // Guard against a concurrent loadInitial that reset the generation counter.
            // Task.isCancelled alone is unreliable if the subprocess finished before the cancel arrived.
            guard !Task.isCancelled, workingTreeGeneration == generation else { return }
            let files = await parseWorkingTreeStatus(data)
            guard !Task.isCancelled, workingTreeGeneration == generation else { return }
            if !files.isEmpty {
                prependSentinelIfNeeded(fileCount: files.count)
            }
        } catch is CancellationError {
            return
        } catch {
            // Non-fatal: working tree sentinel is optional
        }
    }

    private nonisolated func parseWorkingTreeStatus(_ data: Data) async -> [DiffFile] {
        guard !Task.isCancelled else { return [] }
        return GitDiffParser.parseStatusPorcelain(data)
    }

    private func prependSentinelIfNeeded(fileCount: Int) {
        guard searchQuery.isEmpty else { return }
        // Avoid duplicates on rapid refresh
        if commits.first?.isWorkingTreeSentinel == true { return }
        let sentinel = Commit.makeWorkingTreeSentinel(fileCount: fileCount)
        commits.insert(sentinel, at: 0)
        filteredCommits = commits
        if selectedCommit == nil {
            selectedCommit = sentinel
        }
    }

    private func fetchPage(generation: Int) async {
        guard let service = gitService else { return }
        defer {
            if loadingGeneration == generation, isLoading {
                isLoading = false
            }
        }
        // Capture ref, offset, and query so we can verify they haven't changed after the await.
        let ref = currentRef
        let offset = fetchOffset
        let query = searchQuery
        do {
            let output = try await service.fetchLog(ref: ref, limit: pageSize, offset: offset)
            // Guard against branch/repo switch or search activation that completed while the
            // git process was running. Task.isCancelled alone is insufficient if the process
            // finished just before the cancel signal arrived.
            guard !Task.isCancelled, currentRef == ref, fetchOffset == offset, searchQuery == query else { return }
            // Parse and count on a background thread (nonisolated child task inherits cancellation).
            var (newCommits, rawCount) = await parseAndCountLog(output)
            guard !Task.isCancelled, currentRef == ref, fetchOffset == offset, searchQuery == query else { return }
            // Graph layout runs as a nonisolated child task to keep CPU work off MainActor.
            let (laidOut, newLanes) = await computeGraphLayout(commits: newCommits, activeLanes: graphActiveLanes)
            guard !Task.isCancelled, currentRef == ref, fetchOffset == offset, searchQuery == query else { return }
            newCommits = laidOut
            graphActiveLanes = newLanes
            commits.append(contentsOf: newCommits)
            fetchOffset += rawCount
            hasMore = rawCount == pageSize
            if searchQuery.isEmpty {
                filteredCommits = commits
            }
            // Auto-select the first commit when loading the initial page (e.g. after refresh
            // or ref switch), so the detail pane doesn't remain blank.
            if selectedCommit == nil, !filteredCommits.isEmpty {
                selectedCommit = filteredCommits.first
            }
        } catch is CancellationError {
            // Generation check in defer ensures isLoading is only cleared for the current load
        } catch {
            guard currentRef == ref, fetchOffset == offset, searchQuery == query else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func performGlobalSearch(query: String, generation: Int) async {
        guard let service = gitService, !query.isEmpty else { return }
        let mode = searchMode
        defer {
            if loadingGeneration == generation, isLoading {
                isLoading = false
            }
        }
        // Capture ref so a branch switch after the await doesn't mix results.
        let ref = currentRef
        do {
            let results: [Commit]
            if mode == .filePath {
                let output = try await service.fetchLogSearchByPath(ref: ref, path: query)
                guard !Task.isCancelled, searchQuery == query, currentRef == ref else { return }
                results = await parseSearchResults(output)
            } else {
                // Search commit messages (--grep covers subject + body) and author name/email concurrently.
                async let grepTask = service.fetchLogSearch(ref: ref, grep: query)
                async let authorTask = service.fetchLogSearchByAuthor(ref: ref, author: query)
                let grep: String
                do {
                    grep = try await grepTask
                } catch is CancellationError {
                    return
                }
                let author: String
                do {
                    author = try await authorTask
                } catch is CancellationError {
                    return
                } catch {
                    author = ""
                }
                results = await mergeSearchResults(grep: grep, author: author)
            }

            guard searchQuery == query, currentRef == ref else { return }
            filteredCommits = results
            let stillPresent = selectedCommit.map { c in filteredCommits.contains { $0.id == c.id } } ?? false
            if !stillPresent {
                selectedCommit = filteredCommits.first
            }
        } catch is CancellationError {
        } catch {
            guard searchQuery == query, currentRef == ref else { return }
            errorMessage = error.localizedDescription
        }
    }

    // nonisolated async: awaiting from @MainActor suspends the actor and runs the function on
    // the cooperative thread pool (Swift SE-0306 — "nonisolated async runs where the caller
    // is not, i.e. on the cooperative pool when called from an actor").
    // Cancellation is inherited because these run within the same task, not as separate child tasks.

    private nonisolated func computeGraphLayout(commits: [Commit], activeLanes: [String?]) async -> ([Commit], [String?]) {
        guard !Task.isCancelled else { return (commits, activeLanes) }
        var c = commits
        var l = activeLanes
        GraphLayoutEngine.compute(commits: &c, activeLanes: &l)
        return (c, l)
    }

    private nonisolated func parseAndCountLog(_ output: String) async -> ([Commit], Int) {
        guard !Task.isCancelled else { return ([], 0) }
        let commits = GitLogParser.parse(output)
        // Use commits.count as the record count. Git output is always well-formed and
        // malformed records (which would make counts diverge) don't occur in practice.
        return (commits, commits.count)
    }

    private nonisolated func parseSearchResults(_ output: String) async -> [Commit] {
        guard !Task.isCancelled else { return [] }
        return GitLogParser.parse(output)
    }

    private nonisolated func mergeSearchResults(grep: String, author: String) async -> [Commit] {
        var byMessage = GitLogParser.parse(grep)
        let byAuthor = GitLogParser.parse(author)
        var seen = Set(byMessage.map { $0.id })
        for c in byAuthor where !seen.contains(c.id) {
            seen.insert(c.id)
            byMessage.append(c)
        }
        byMessage.sort { $0.committerDate > $1.committerDate }
        return byMessage
    }
}
