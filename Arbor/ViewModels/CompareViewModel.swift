import Foundation
import Observation

@MainActor
@Observable
final class CompareViewModel {
    var baseRef: GitRef?
    var targetRef: GitRef?
    var changedFiles: [DiffFile] = []
    var selectedFile: DiffFile?
    var diffHunks: [DiffHunk] = []
    var currentRawDiff: String?
    var isLoadingFiles: Bool = false
    var isLoadingDiff: Bool = false
    var errorMessage: String?
    var diffInfoMessage: String?
    var diffStat: String?

    private var gitService: GitService?
    private var fileTask: Task<Void, Never>?
    private var diffTask: Task<Void, Never>?
    private var fileGeneration: Int = 0
    private var diffGeneration: Int = 0

    func cancelAll() {
        fileTask?.cancel()
        diffTask?.cancel()
    }

    func clear() {
        cancelAll()
        changedFiles = []
        selectedFile = nil
        diffHunks = []
        currentRawDiff = nil
        isLoadingFiles = false
        isLoadingDiff = false
        errorMessage = nil
        diffInfoMessage = nil
        diffStat = nil
    }

    func load(baseRef: GitRef, targetRef: GitRef, service: GitService) {
        fileTask?.cancel()
        diffTask?.cancel()
        self.baseRef = baseRef
        self.targetRef = targetRef
        self.gitService = service
        changedFiles = []
        selectedFile = nil
        diffHunks = []
        currentRawDiff = nil
        isLoadingFiles = true
        isLoadingDiff = false
        errorMessage = nil
        diffInfoMessage = nil
        diffStat = nil
        fileGeneration += 1
        let fileGen = fileGeneration
        let base = baseRef.gitRef
        let target = targetRef.gitRef
        fileTask = Task { [weak self] in
            defer {
                if let s = self, s.fileGeneration == fileGen, s.isLoadingFiles {
                    s.isLoadingFiles = false
                }
            }
            do {
                async let filesTask = service.fetchDiffBetweenRefs(baseRef: base, targetRef: target)
                async let statTask = service.fetchDiffStatBetweenRefs(baseRef: base, targetRef: target)
                let rawOutput = try await filesTask
                guard let self, !Task.isCancelled else { return }
                let files = await self.parseNameStatus(rawOutput)
                guard !Task.isCancelled else { return }
                let stat: String
                do { stat = try await statTask } catch is CancellationError { return } catch { stat = "" }
                guard !Task.isCancelled else { return }
                self.changedFiles = files
                self.diffStat = stat.isEmpty ? nil : stat
                self.isLoadingFiles = false
                if let first = files.first {
                    self.selectFile(first)
                }
            } catch is CancellationError {
                return
            } catch {
                guard let self else { return }
                self.isLoadingFiles = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func selectNextFile() {
        guard !changedFiles.isEmpty,
              let current = selectedFile,
              let idx = changedFiles.firstIndex(where: { $0.id == current.id }),
              idx + 1 < changedFiles.count else { return }
        selectFile(changedFiles[idx + 1])
    }

    func selectPreviousFile() {
        guard !changedFiles.isEmpty,
              let current = selectedFile,
              let idx = changedFiles.firstIndex(where: { $0.id == current.id }),
              idx > 0 else { return }
        selectFile(changedFiles[idx - 1])
    }

    func selectFile(_ file: DiffFile) {
        guard let service = gitService,
              let base = baseRef, let target = targetRef else { return }
        let baseGitRef = base.gitRef
        let targetGitRef = target.gitRef
        let fileID = file.id
        diffTask?.cancel()
        selectedFile = file
        diffHunks = []
        currentRawDiff = nil
        diffInfoMessage = nil
        errorMessage = nil
        isLoadingDiff = true
        diffGeneration += 1
        let diffGen = diffGeneration
        diffTask = Task { [weak self] in
            defer {
                if let s = self, s.diffGeneration == diffGen, s.isLoadingDiff {
                    s.isLoadingDiff = false
                }
            }
            do {
                let output = try await service.fetchDiffContentBetweenRefs(
                    baseRef: baseGitRef, targetRef: targetGitRef, rawPath: file.rawNewPath
                )
                guard let self, !Task.isCancelled, self.selectedFile?.id == fileID else { return }
                let result = await self.parseDiff(output)
                guard !Task.isCancelled, self.selectedFile?.id == fileID else { return }
                self.diffInfoMessage = result.isBinary
                    ? "バイナリファイルのため差分を表示できません"
                    : result.infoMessage
                self.diffHunks = result.hunks
                if !result.hunks.isEmpty { self.currentRawDiff = output }
                self.isLoadingDiff = false
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.selectedFile?.id == fileID else { return }
                if case .outputTooLarge? = error as? GitError {
                    self.diffInfoMessage = "ファイルが大きすぎるため差分を表示できません"
                } else {
                    self.diffInfoMessage = "差分を取得できません（バイナリまたはファイル不在）"
                }
                self.diffHunks = []
                self.isLoadingDiff = false
            }
        }
    }

    private nonisolated func parseNameStatus(_ data: Data) async -> [DiffFile] {
        guard !Task.isCancelled else { return [] }
        return GitDiffParser.parseNameStatus(data)
    }

    private nonisolated func parseDiff(_ output: String) async -> (hunks: [DiffHunk], infoMessage: String?, isBinary: Bool) {
        guard !Task.isCancelled else { return ([], nil, false) }
        if output.contains("\nBinary files ") || output.hasPrefix("Binary files ")
            || output.contains("\nGIT binary patch") || output.hasPrefix("GIT binary patch") {
            return ([], nil, true)
        }
        let hunks = GitDiffParser.parseDiffContent(output)
        if hunks.isEmpty {
            let hasMetadata = output.contains("\nrename from ") || output.contains("\nrename to ")
                || output.contains("\ncopy from ") || output.contains("\ncopy to ")
                || output.contains("\nnew file mode ") || output.contains("\ndeleted file mode ")
                || output.contains("\nnew mode ") || output.contains("\nold mode ")
                || output.contains("\nsimilarity index ")
            return ([], hasMetadata ? "内容変更なし（ファイルモード・名前変更のみ）" : nil, false)
        }
        return (hunks, nil, false)
    }
}
