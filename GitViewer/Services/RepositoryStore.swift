import Foundation

// Phase 2: Persist repository list to UserDefaults
final class RepositoryStore {
    static let shared = RepositoryStore()

    private let key = "savedRepositories"

    func save(_ repositories: [Repository]) {
        // TODO: Implement in Phase 2
    }

    func load() -> [Repository] {
        // TODO: Implement in Phase 2
        return []
    }
}
