import Foundation

final class RepositoryStore {
    static let shared = RepositoryStore()
    private let key = "savedRepositories"

    func save(_ repositories: [Repository]) {
        guard let data = try? JSONEncoder().encode(repositories) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func load() -> (repos: [Repository], error: String?) {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return ([], nil)
        }
        do {
            let repos = try JSONDecoder().decode([Repository].self, from: data)
            return (repos, nil)
        } catch {
            // Persisted data is unreadable (e.g. schema mismatch after update).
            // Return empty list and surface the error so the UI can inform the user.
            return ([], "保存済みリポジトリの読み込みに失敗しました: \(error.localizedDescription)")
        }
    }
}
