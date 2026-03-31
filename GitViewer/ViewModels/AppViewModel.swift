import Foundation
import Observation

@MainActor
@Observable
final class AppViewModel {
    var repositories: [Repository] = []
    var selectedRepository: Repository?
    var sidebarVM: SidebarViewModel?
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
            }
        }
    }

    func selectRepository(_ repo: Repository) {
        selectedRepository = repo
        let vm = SidebarViewModel()
        sidebarVM = vm
        let service = GitService(repositoryURL: repo.path)
        loadTask?.cancel()
        loadTask = Task {
            await vm.load(service: service)
        }
    }
}
