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
    private(set) var gitService: GitService?
    private var loadTask: Task<Void, Never>?

    init() {
        repositories = RepositoryStore.shared.load()
        if let first = repositories.first {
            selectRepository(first)
        }
    }

    func addRepository(at url: URL) async throws {
        guard !repositories.contains(where: { $0.path == url }) else { return }
        let service = GitService(repositoryURL: url)
        try await service.validateRepository()
        let headBranch = try await service.fetchHeadBranch()
        var repo = Repository(path: url)
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
        if selectedRepository?.id == repo.id {
            if let first = repositories.first {
                selectRepository(first)
            } else {
                selectedRepository = nil
                sidebarVM = nil
                commitListVM = nil
                detailVM = nil
                gitService = nil
            }
        }
    }

    func selectRepository(_ repo: Repository) {
        selectedRepository = repo
        let service = GitService(repositoryURL: repo.path)
        gitService = service
        let sidebar = SidebarViewModel()
        sidebarVM = sidebar
        commitListVM = CommitListViewModel()
        detailVM = DetailViewModel()
        loadTask?.cancel()
        loadTask = Task {
            await sidebar.load(service: service)
        }
    }

    func refresh() {
        guard let service = gitService, let sidebar = sidebarVM else { return }
        if let ref = sidebar.selectedRef, let commitList = commitListVM {
            commitList.loadInitial(ref: ref.gitRef, service: service)
        }
        loadTask?.cancel()
        loadTask = Task {
            await sidebar.load(service: service)
        }
    }
}
