import Foundation
import Observation

@MainActor
@Observable
final class CommitListViewModel {
    let instanceID = UUID()  // changes on every selectRepository, used as task(id:) key

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

    func loadInitial(ref: String, service: GitService) {
        loadTask?.cancel()
        commits = []
        filteredCommits = []
        fetchOffset = 0
        hasMore = true
        selectedCommit = nil
        errorMessage = nil
        currentRef = ref
        gitService = service
        loadTask = Task { await self.fetchPage() }
    }

    func loadMore() {
        guard !isLoading, hasMore, gitService != nil else { return }
        loadTask = Task { await self.fetchPage() }
    }

    func updateSearch(_ query: String) {
        searchQuery = query
        applyFilter()
    }

    private func fetchPage() async {
        guard let service = gitService else { return }
        isLoading = true
        do {
            let output = try await service.fetchLog(ref: currentRef, limit: pageSize, offset: fetchOffset)
            let parsed = GitLogParser.parse(output)
            commits.append(contentsOf: parsed)
            fetchOffset += parsed.count
            hasMore = parsed.count == pageSize
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
