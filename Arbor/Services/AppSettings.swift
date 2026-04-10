import AppKit
import Observation

@MainActor
@Observable
final class AppSettings {
    // 0 = system, 1 = light, 2 = dark
    var appearanceMode: Int {
        didSet {
            UserDefaults.standard.set(appearanceMode, forKey: "appearanceMode")
            applyAppearance()
        }
    }
    var showAbsoluteDates: Bool {
        didSet { UserDefaults.standard.set(showAbsoluteDates, forKey: "showAbsoluteDates") }
    }
    var isRepositoriesCollapsed: Bool {
        didSet { UserDefaults.standard.set(isRepositoriesCollapsed, forKey: "isRepositoriesCollapsed") }
    }
    var isBranchesCollapsed: Bool {
        didSet { UserDefaults.standard.set(isBranchesCollapsed, forKey: "isBranchesCollapsed") }
    }
    var isRemotesCollapsed: Bool {
        didSet { UserDefaults.standard.set(isRemotesCollapsed, forKey: "isRemotesCollapsed") }
    }
    var isTagsCollapsed: Bool {
        didSet { UserDefaults.standard.set(isTagsCollapsed, forKey: "isTagsCollapsed") }
    }
    var isStashesCollapsed: Bool {
        didSet { UserDefaults.standard.set(isStashesCollapsed, forKey: "isStashesCollapsed") }
    }
    var showFileTree: Bool {
        didSet { UserDefaults.standard.set(showFileTree, forKey: "showFileTree") }
    }
    var showSplitDiff: Bool {
        didSet { UserDefaults.standard.set(showSplitDiff, forKey: "showSplitDiff") }
    }
    var showGravatar: Bool {
        didSet { UserDefaults.standard.set(showGravatar, forKey: "showGravatar") }
    }
    var diffTabWidth: Int {
        didSet {
            let clamped = max(1, min(diffTabWidth, 16))
            if clamped != diffTabWidth { diffTabWidth = clamped; return }
            UserDefaults.standard.set(diffTabWidth, forKey: "diffTabWidth")
        }
    }
    var diffFontSize: Double {
        didSet {
            let clamped = max(8, min(diffFontSize, 24))
            if clamped != diffFontSize { diffFontSize = clamped; return }
            UserDefaults.standard.set(diffFontSize, forKey: "diffFontSize")
        }
    }
    var diffLineSpacing: Double {
        didSet {
            let clamped = max(0, min(diffLineSpacing, 8))
            if clamped != diffLineSpacing { diffLineSpacing = clamped; return }
            UserDefaults.standard.set(diffLineSpacing, forKey: "diffLineSpacing")
        }
    }
    var graphLaneWidth: Double {
        didSet {
            let clamped = max(6, min(graphLaneWidth, 40))
            if clamped != graphLaneWidth { graphLaneWidth = clamped; return }
            UserDefaults.standard.set(graphLaneWidth, forKey: "graphLaneWidth")
        }
    }
    var useCustomGitPath: Bool {
        didSet { UserDefaults.standard.set(useCustomGitPath, forKey: "useCustomGitPath") }
    }
    var customGitPath: String {
        didSet { UserDefaults.standard.set(customGitPath, forKey: "customGitPath") }
    }

    var effectiveGitPath: String? {
        guard useCustomGitPath else { return nil }
        let trimmed = customGitPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, FileManager.default.isExecutableFile(atPath: trimmed) else { return nil }
        return trimmed
    }

    init() {
        appearanceMode = UserDefaults.standard.integer(forKey: "appearanceMode")
        showAbsoluteDates = UserDefaults.standard.bool(forKey: "showAbsoluteDates")
        isRepositoriesCollapsed = UserDefaults.standard.bool(forKey: "isRepositoriesCollapsed")
        isBranchesCollapsed = UserDefaults.standard.bool(forKey: "isBranchesCollapsed")
        isRemotesCollapsed = UserDefaults.standard.bool(forKey: "isRemotesCollapsed")
        isTagsCollapsed = UserDefaults.standard.bool(forKey: "isTagsCollapsed")
        isStashesCollapsed = UserDefaults.standard.bool(forKey: "isStashesCollapsed")
        showFileTree = UserDefaults.standard.bool(forKey: "showFileTree")
        showSplitDiff = UserDefaults.standard.bool(forKey: "showSplitDiff")
        showGravatar = UserDefaults.standard.object(forKey: "showGravatar") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "showGravatar")
        diffTabWidth = UserDefaults.standard.object(forKey: "diffTabWidth") != nil
            ? max(1, min(UserDefaults.standard.integer(forKey: "diffTabWidth"), 16))
            : 4
        diffFontSize = UserDefaults.standard.object(forKey: "diffFontSize") != nil
            ? max(8, min(UserDefaults.standard.double(forKey: "diffFontSize"), 24))
            : 11
        diffLineSpacing = UserDefaults.standard.object(forKey: "diffLineSpacing") != nil
            ? max(0, min(UserDefaults.standard.double(forKey: "diffLineSpacing"), 8))
            : 1
        let storedLaneWidth = UserDefaults.standard.double(forKey: "graphLaneWidth")
        graphLaneWidth = max(6, min(storedLaneWidth > 0 ? storedLaneWidth : 14, 40))
        useCustomGitPath = UserDefaults.standard.bool(forKey: "useCustomGitPath")
        customGitPath = UserDefaults.standard.string(forKey: "customGitPath") ?? ""
        // Apply persisted appearance before the first frame renders.
        applyAppearance()
    }

    func applyAppearance() {
        guard NSApp != nil else { return }
        switch appearanceMode {
        case 1: NSApp.appearance = NSAppearance(named: .aqua)
        case 2: NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
    }
}
