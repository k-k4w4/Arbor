import Foundation

final class RepositoryStore {
    static let shared = RepositoryStore()
    private let key = "savedRepositories"

    func save(_ repositories: [Repository]) {
        let data = try? JSONEncoder().encode(repositories)
        UserDefaults.standard.set(data, forKey: key)
    }

    func load() -> [Repository] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let repos = try? JSONDecoder().decode([Repository].self, from: data) else {
            return []
        }
        return repos
    }
}
