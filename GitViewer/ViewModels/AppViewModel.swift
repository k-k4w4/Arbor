import Foundation
import Observation

@MainActor
@Observable
final class AppViewModel {
    var repositories: [Repository] = []
    var selectedRepository: Repository?
    var sidebarVM: SidebarViewModel?
    var commitListVM: CommitListViewModel?
    var detailVM: DetailViewModel?
    var errorMessage: String?

    var windowTitle: String {
        guard let repo = selectedRepository else { return "GitViewer" }
        let repoName = repo.path.lastPathComponent
        guard let ref = sidebarVM?.selectedRef else { return repoName }
        // Use shortName ("main") not gitRef ("refs/heads/main") for display.
        return "\(repoName) — \(ref.shortName)"
    }
    private(set) var gitService: GitService?
    private var refObserveGeneration = 0

    init() {
        let result = RepositoryStore.shared.load()
        repositories = result.repos
        if let msg = result.error {
            errorMessage = msg
        }
        if let first = repositories.first {
            selectRepository(first)
        }
    }

    func addRepository(at url: URL) async throws {
        // Normalize to resolve symlinks and remove ".." so the same repo added via
        // different path representations is detected as a duplicate.
        let normalized = url.standardizedFileURL.resolvingSymlinksInPath()
        guard !repositories.contains(where: { $0.path.standardizedFileURL.resolvingSymlinksInPath() == normalized }) else { return }
        let service = try GitService(repositoryURL: normalized)
        try await service.validateRepository()
        let headBranch = try await service.fetchHeadBranch()
        // Re-check after awaits: another concurrent call may have added the same URL.
        guard !repositories.contains(where: { $0.path.standardizedFileURL.resolvingSymlinksInPath() == normalized }) else { return }
        var repo = Repository(path: normalized)
        repo.headBranchName = headBranch
        repositories.append(repo)
        RepositoryStore.shared.save(repositories)
        if selectedRepository == nil {
            selectRepository(repo)
        }
    }

    func removeRepository(_ repo: Repository) {
        repositories.removeAll { $0.id == repo.id }
        RepositoryStore.shared.save(repositories)
        guard selectedRepository?.id == repo.id else { return }
        // Clear state first so if selectRepository fails (GitService init error),
        // the UI shows an empty/reset state rather than stale data for the deleted repo.
        sidebarVM?.cancelAll()
        commitListVM?.cancelAll()
        detailVM?.cancelAll()
        selectedRepository = nil
        sidebarVM = nil
        commitListVM = nil
        detailVM = nil
        gitService = nil
        if let first = repositories.first {
            selectRepository(first)
        }
    }

    func selectRepository(_ repo: Repository) {
        // Create the service first; only update state on success so the selection
        // remains consistent with the active git service.
        let service: GitService
        do {
            service = try GitService(repositoryURL: repo.path)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        // Cancel in-flight tasks only after the new service is confirmed ready,
        // so a failed init doesn't leave the UI in a stopped-but-unchanged state.
        sidebarVM?.cancelAll()
        commitListVM?.cancelAll()
        detailVM?.cancelAll()
        selectedRepository = repo
        gitService = service
        let sidebar = SidebarViewModel()
        sidebarVM = sidebar
        commitListVM = CommitListViewModel()
        detailVM = DetailViewModel()
        sidebar.scheduleLoad(service: service)
        refObserveGeneration += 1
        observeRefAndLoadCommits()
    }

    // Watch sidebarVM.selectedRef changes and trigger commit loading.
    // Uses withObservationTracking so it works regardless of whether SwiftUI
    // re-renders CommitListView in time (nested @Observable chains can miss updates).
    private func observeRefAndLoadCommits() {
        let gen = refObserveGeneration
        withObservationTracking {
            _ = self.sidebarVM?.selectedRef
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.refObserveGeneration == gen else { return }
                // Re-register before loading to minimize the window where a rapid
                // branch switch could be missed between onChange firing and re-registration.
                self.observeRefAndLoadCommits()
                if let ref = self.sidebarVM?.selectedRef,
                   let commitList = self.commitListVM,
                   let service = self.gitService,
                   ref.gitRef != commitList.currentRef {
                    commitList.loadInitial(ref: ref.gitRef, service: service)
                }
            }
        }
    }

    func refresh() {
        guard let service = gitService, let sidebar = sidebarVM else { return }
        if let ref = sidebar.selectedRef, let commitList = commitListVM {
            commitList.loadInitial(ref: ref.gitRef, service: service)
        }
        sidebar.scheduleLoad(service: service)
    }
}
