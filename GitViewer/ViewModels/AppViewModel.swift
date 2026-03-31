import Foundation
import Observation

@MainActor
@Observable
final class AppViewModel {
    var repositories: [Repository] = []
    var selectedRepository: Repository?

    func addRepository(at url: URL) async throws {
        let service = GitService(repositoryURL: url)
        try await service.validateRepository()
        let headBranch = try await service.fetchHeadBranch()
        var repo = Repository(path: url)
        repo.headBranchName = headBranch
        repositories.append(repo)
        if selectedRepository == nil {
            selectedRepository = repo
        }
    }

    func removeRepository(_ repo: Repository) {
        repositories.removeAll { $0.id == repo.id }
        if selectedRepository?.id == repo.id {
            selectedRepository = repositories.first
        }
    }
}
