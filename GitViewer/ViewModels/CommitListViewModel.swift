import Foundation
import Observation

// Phase 3: Commit list state
@MainActor
@Observable
final class CommitListViewModel {
    var commits: [Commit] = []
    var filteredCommits: [Commit] = []
    var selectedCommit: Commit?
    var searchQuery: String = ""
    var isLoading: Bool = false
    var hasMore: Bool = true
}
