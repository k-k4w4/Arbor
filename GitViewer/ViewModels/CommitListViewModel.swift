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
    private var gitService: GitService?
    private var graphActiveLanes: [String?] = []  // incremental graph state across pages

    func cancelAll() {
        loadTask?.cancel()
    }

    func loadInitial(ref: String, service: GitService) {
        loadTask?.cancel()
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
        loadTask = Task { await self.fetchPage() }
    }

    func loadMore() {
        guard !isLoading, hasMore, gitService != nil else { return }
        loadTask?.cancel()
        isLoading = true
        loadTask = Task { await self.fetchPage() }
    }

    func updateSearch(_ query: String) {
        searchQuery = query
        applyFilter()
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
            applyFilter()
            isLoading = false
        } catch is CancellationError {
            // Newer loadInitial is managing isLoading; don't touch it
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func applyFilter() {
        if searchQuery.isEmpty {
            filteredCommits = commits
        } else {
            let q = searchQuery.lowercased()
            filteredCommits = commits.filter {
                $0.subject.lowercased().contains(q) ||
                $0.authorName.lowercased().contains(q) ||
                $0.shortSHA.lowercased().contains(q)
            }
        }
    }
}
