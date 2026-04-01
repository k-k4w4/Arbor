import Foundation
import Observation

@MainActor
@Observable
final class CommitListViewModel {
    var commits: [Commit] = []
    var filteredCommits: [Commit] = []
    var selectedCommit: Commit?
    var searchQuery: String = ""
    var isLoading: Bool = false
    var hasMore: Bool = true
    var errorMessage: String?

    private var currentRef: String = "HEAD"
    private var fetchOffset: Int = 0
    private let pageSize = 200
    private var loadTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var gitService: GitService?
    private var graphActiveLanes: [String?] = []  // incremental graph state across pages

    func cancelAll() {
        loadTask?.cancel()
        searchTask?.cancel()
    }

    func loadInitial(ref: String, service: GitService) {
        loadTask?.cancel()
        searchTask?.cancel()
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
        loadTask = Task { await self.fetchPage() }
    }

    func loadMore() {
        guard !isLoading, hasMore, gitService != nil, searchQuery.isEmpty else { return }
        loadTask?.cancel()
        isLoading = true
        loadTask = Task { await self.fetchPage() }
    }

    // Called from view's onChange(of: searchQuery) — fires only on actual value changes,
    // not on spurious focus events that macOS searchable may emit.
    func searchQueryChanged(_ query: String) {
        searchTask?.cancel()
        if query.isEmpty {
            // loadInitial clears commits before setting searchQuery = "".
            // If commits is empty here, loadInitial just ran and loadTask is managing
            // isLoading — don't interfere.
            if !commits.isEmpty {
                filteredCommits = commits
                isLoading = false
            }
        } else {
            loadTask?.cancel()
            filteredCommits = []
            isLoading = true
            searchTask = Task {
                do { try await Task.sleep(nanoseconds: 300_000_000) } catch {
                    return  // Cancelled; caller already manages isLoading
                }
                await self.performGlobalSearch(query: query)
            }
        }
    }

    private func fetchPage() async {
        guard let service = gitService else { return }
        do {
            let output = try await service.fetchLog(ref: currentRef, limit: pageSize, offset: fetchOffset)
            var newCommits = GitLogParser.parse(output)
            // Use raw record count (not parsed count) so fetchOffset stays aligned with git's
            // --skip regardless of parse failures; prevents duplicates on subsequent pages.
            let rawCount = output.components(separatedBy: "\u{1E}").filter {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }.count
            GraphLayoutEngine.compute(commits: &newCommits, activeLanes: &graphActiveLanes)
            commits.append(contentsOf: newCommits)
            fetchOffset += rawCount
            hasMore = rawCount == pageSize
            if searchQuery.isEmpty {
                filteredCommits = commits
            }
            isLoading = false
        } catch is CancellationError {
            // Newer loadInitial is managing isLoading; don't touch it
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func performGlobalSearch(query: String) async {
        guard let service = gitService, !query.isEmpty else { return }
        do {
            // Search commit messages (--grep covers subject + body) and author name/email concurrently
            async let grepOutput = service.fetchLogSearch(ref: currentRef, grep: query)
            async let authorOutput = service.fetchLogSearchByAuthor(ref: currentRef, author: query)
            let (grep, author) = try await (grepOutput, authorOutput)

            var byMessage = GitLogParser.parse(grep)
            let byAuthor = GitLogParser.parse(author)

            // Merge, deduplicate by SHA, sort by author date descending
            var seen = Set(byMessage.map { $0.id })
            for c in byAuthor where !seen.contains(c.id) {
                seen.insert(c.id)
                byMessage.append(c)
            }
            byMessage.sort { $0.authorDate > $1.authorDate }

            guard searchQuery == query else { isLoading = false; return }
            filteredCommits = byMessage
            isLoading = false
        } catch is CancellationError {
        } catch {
            guard searchQuery == query else { isLoading = false; return }
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
