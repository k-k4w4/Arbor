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
        // Try full decode first (fast path).
        if let repos = try? JSONDecoder().decode([Repository].self, from: data) {
            return (repos, nil)
        }
        // Full decode failed (e.g. partial schema mismatch). Try element-by-element to
        // salvage valid entries rather than discarding everything.
        if let rawArray = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] {
            let salvaged = rawArray.compactMap { dict -> Repository? in
                guard let elemData = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
                return try? JSONDecoder().decode(Repository.self, from: elemData)
            }
            if !salvaged.isEmpty {
                save(salvaged)  // Overwrite with valid entries to prevent repeated errors
                return (salvaged, nil)
            }
            // JSON is valid but no entries decoded (e.g. schema change); preserve raw data
            // so a rollback can recover it — just surface the error without deleting.
            return ([], "保存済みリポジトリの読み込みに失敗しました")
        }
        // Truly unreadable JSON — remove to prevent the same error on every launch.
        UserDefaults.standard.removeObject(forKey: key)
        return ([], "保存済みリポジトリの読み込みに失敗しました")
    }
}
