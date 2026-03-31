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
    private(set) var gitService: GitService?

    init() {
        repositories = RepositoryStore.shared.load()
        if let first = repositories.first {
            selectRepository(first)
        }
    }

    func addRepository(at url: URL) async throws {
        guard !repositories.contains(where: { $0.path == url }) else { return }
        let service = try GitService(repositoryURL: url)
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
        // Cancel all in-flight tasks on old VMs before replacing them
        sidebarVM?.cancelAll()
        commitListVM?.cancelAll()
        detailVM?.cancelAll()
        selectedRepository = repo
        do {
            gitService = try GitService(repositoryURL: repo.path)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        guard let service = gitService else { return }
        let sidebar = SidebarViewModel()
        sidebarVM = sidebar
        commitListVM = CommitListViewModel()
        detailVM = DetailViewModel()
        sidebar.scheduleLoad(service: service)
    }

    func refresh() {
        guard let service = gitService, let sidebar = sidebarVM else { return }
        if let ref = sidebar.selectedRef, let commitList = commitListVM {
            commitList.loadInitial(ref: ref.gitRef, service: service)
        }
        sidebar.scheduleLoad(service: service)
    }
}
