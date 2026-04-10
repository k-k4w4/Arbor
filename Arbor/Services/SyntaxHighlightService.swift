import Foundation
import HighlightSwift

actor SyntaxHighlightService {
    static let shared = SyntaxHighlightService()

    private let highlight = Highlight()
    private var cache: [String: AttributedString] = [:]
    private var cacheKeys: [String] = []
    private let maxCacheSize = 2000

    func highlight(_ text: String, language: String?, isDark: Bool) async -> AttributedString? {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let cacheKey = "\(isDark ? "d" : "l")\0\(language ?? "")\0\(text)"
        if let cached = cache[cacheKey] { return cached }
        do {
            let mode: HighlightMode = language.map { .languageAlias($0) } ?? .automatic
            let colors: HighlightColors = isDark ? .dark(.xcode) : .light(.xcode)
            let result = try await highlight.request(text, mode: mode, colors: colors)
            let attributed = result.attributedText
            cache[cacheKey] = attributed
            cacheKeys.append(cacheKey)
            if cacheKeys.count > maxCacheSize {
                let removeKey = cacheKeys.removeFirst()
                cache.removeValue(forKey: removeKey)
            }
            return attributed
        } catch {
            return nil
        }
    }

    func clearCache() {
        cache.removeAll()
        cacheKeys.removeAll()
    }

    static func language(for filename: String) -> String? {
        let ext = (filename as NSString).pathExtension.lowercased()
        return extensionMap[ext]
    }

    private static let extensionMap: [String: String] = [
        "swift": "swift",
        "py": "python",
        "js": "javascript",
        "jsx": "javascript",
        "ts": "typescript",
        "tsx": "typescript",
        "rb": "ruby",
        "go": "go",
        "rs": "rust",
        "java": "java",
        "kt": "kotlin",
        "kts": "kotlin",
        "c": "c",
        "h": "c",
        "cpp": "cpp",
        "cc": "cpp",
        "cxx": "cpp",
        "hpp": "cpp",
        "hxx": "cpp",
        "m": "objectivec",
        "mm": "objectivec",
        "cs": "csharp",
        "php": "php",
        "scala": "scala",
        "sh": "bash",
        "bash": "bash",
        "zsh": "bash",
        "yml": "yaml",
        "yaml": "yaml",
        "json": "json",
        "xml": "xml",
        "html": "html",
        "htm": "html",
        "css": "css",
        "scss": "scss",
        "less": "less",
        "sql": "sql",
        "md": "markdown",
        "markdown": "markdown",
        "r": "r",
        "lua": "lua",
        "pl": "perl",
        "pm": "perl",
        "ex": "elixir",
        "exs": "elixir",
        "erl": "erlang",
        "hs": "haskell",
        "clj": "clojure",
        "dart": "dart",
        "toml": "toml",
        "ini": "ini",
        "dockerfile": "dockerfile",
        "makefile": "makefile",
        "cmake": "cmake",
        "groovy": "groovy",
        "gradle": "groovy",
        "tf": "hcl",
        "vim": "vim",
        "el": "lisp",
        "lisp": "lisp",
    ]
}
