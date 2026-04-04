import Foundation
import CryptoKit
import AppKit

actor GravatarCache {
    static let shared = GravatarCache()

    private var cache: [String: NSImage?] = [:]
    // Coalesce concurrent requests for the same email into one network call.
    private var inflight: [String: Task<NSImage?, Never>] = [:]

    // Short timeout: Gravatar is a non-critical decoration; don't block the UI.
    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 8
        cfg.timeoutIntervalForResource = 15
        return URLSession(configuration: cfg)
    }()

    func image(for email: String) async -> NSImage? {
        let key = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }

        // Use index(forKey:) for O(1) presence check that distinguishes
        // "cached nil" (failed/404) from "not yet requested".
        if cache.index(forKey: key) != nil { return cache[key] ?? nil }

        if let task = inflight[key] {
            return await task.value
        }

        // actor is a reference type — no [weak self] needed or wanted.
        let task = Task<NSImage?, Never> {
            await self.fetch(key: key)
        }
        inflight[key] = task
        let result = await task.value
        cache[key] = result
        inflight.removeValue(forKey: key)
        return result
    }

    private func fetch(key email: String) async -> NSImage? {
        let digest = Insecure.MD5.hash(data: Data(email.utf8))
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        // d=404: receive HTTP 404 (not the generic silhouette) when no avatar exists.
        guard let url = URL(string: "https://www.gravatar.com/avatar/\(hash)?s=80&d=404") else {
            return nil
        }
        do {
            let (data, response) = try await GravatarCache.session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            return NSImage(data: data)
        } catch {
            return nil
        }
    }
}
