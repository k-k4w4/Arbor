import Foundation
import Observation

@MainActor
@Observable
final class DetailViewModel {
    var commit: Commit?
    var commitBody: String = ""
    var changedFiles: [DiffFile] = []
    var selectedFile: DiffFile?
    var diffHunks: [DiffHunk] = []
    var isLoadingFiles: Bool = false
    var isLoadingDiff: Bool = false
    var errorMessage: String?
    var diffInfoMessage: String?

    private var gitService: GitService?
    private var fileTask: Task<Void, Never>?
    private var diffTask: Task<Void, Never>?
    private var bodyTask: Task<Void, Never>?

    func cancelAll() {
        fileTask?.cancel()
        diffTask?.cancel()
        bodyTask?.cancel()
    }

    func clear() {
        fileTask?.cancel()
        diffTask?.cancel()
        bodyTask?.cancel()
        commit = nil
        commitBody = ""
        changedFiles = []
        selectedFile = nil
        diffHunks = []
        isLoadingFiles = false
        isLoadingDiff = false
        errorMessage = nil
        diffInfoMessage = nil
    }

    func load(commit: Commit, service: GitService) {
        fileTask?.cancel()
        diffTask?.cancel()
        bodyTask?.cancel()
        self.commit = commit
        self.gitService = service
        commitBody = ""
        changedFiles = []
        selectedFile = nil
        diffHunks = []
        isLoadingFiles = true
        isLoadingDiff = false
        errorMessage = nil
        diffInfoMessage = nil

        if commit.isWorkingTreeSentinel {
            loadWorkingTree(service: service, commitID: commit.id)
            return
        }

        fileTask = Task { [weak self] in
            do {
                let rawOutput = try await service.fetchDiff(commit: commit.id)
                // Verify commit hasn't changed since the request was made.
                guard let self, !Task.isCancelled, self.commit?.id == commit.id else { return }
                // Parse file list off MainActor (nonisolated child task inherits cancellation).
                let files = await parseNameStatus(rawOutput)
                guard !Task.isCancelled, self.commit?.id == commit.id else { return }
                self.changedFiles = files
                self.isLoadingFiles = false
                if let first = files.first {
                    self.selectFile(first)
                }
            } catch is CancellationError {
                // clear() or the next load() manages isLoadingFiles; don't overwrite here.
                return
            } catch {
                guard let self, self.commit?.id == commit.id else { return }
                self.isLoadingFiles = false
                self.errorMessage = error.localizedDescription
            }
        }
        bodyTask = Task { [weak self] in
            do {
                let body = try await service.fetchCommitBody(sha: commit.id)
                guard let self, !Task.isCancelled, self.commit?.id == commit.id else { return }
                self.commitBody = body
            } catch is CancellationError {
                return
            } catch {
                // Body is non-critical; silently ignore git errors
            }
        }
    }

    private func loadWorkingTree(service: GitService, commitID: String) {
        fileTask = Task { [weak self] in
            do {
                let data = try await service.fetchWorkingTreeStatus()
                guard let self, !Task.isCancelled, self.commit?.id == commitID else { return }
                let files = await parseWorkingTreeStatus(data)
                guard !Task.isCancelled, self.commit?.id == commitID else { return }
                self.changedFiles = files
                self.isLoadingFiles = false
                if let first = files.first {
                    self.selectFile(first)
                }
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.commit?.id == commitID else { return }
                self.isLoadingFiles = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func selectFile(_ file: DiffFile) {
        guard let service = gitService, let commit = commit else { return }
        let commitID = commit.id
        let fileID = file.id
        diffTask?.cancel()
        selectedFile = file
        diffHunks = []
        diffInfoMessage = nil
        errorMessage = nil
        isLoadingDiff = true
        diffTask = Task { [weak self] in
            do {
                // Untracked files: no diff available from git diff
                if file.status == .untracked {
                    guard let self, !Task.isCancelled, self.selectedFile?.id == fileID else { return }
                    self.diffInfoMessage = "追跡されていないファイルです（差分なし）"
                    self.diffHunks = []
                    self.isLoadingDiff = false
                    return
                }

                let output: String
                if let staged = file.staged {
                    // Working tree diff: staged or unstaged
                    output = staged
                        ? try await service.fetchStagedDiff(rawPath: file.rawNewPath)
                        : try await service.fetchUnstagedDiff(rawPath: file.rawNewPath)
                    guard let self, !Task.isCancelled,
                          self.commit?.id == commitID,
                          self.selectedFile?.id == fileID else { return }
                } else {
                    // Commit diff
                    output = try await service.fetchDiffContent(commit: commitID, rawPath: file.rawNewPath)
                    guard let self, !Task.isCancelled,
                          self.commit?.id == commitID,
                          self.selectedFile?.id == fileID else { return }
                }

                let result = await parseDiff(output)
                guard let self, !Task.isCancelled,
                      self.commit?.id == commitID,
                      self.selectedFile?.id == fileID else { return }
                self.diffInfoMessage = result.infoMessage
                self.diffHunks = result.hunks
                self.isLoadingDiff = false
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.commit?.id == commitID, self.selectedFile?.id == fileID else { return }
                if case .outputTooLarge? = error as? GitError {
                    self.diffInfoMessage = "ファイルが大きすぎるため差分を表示できません"
                    self.diffHunks = []
                } else {
                    // Binary or otherwise unreadable: show fallback instead of error
                    self.diffInfoMessage = "差分を取得できません（バイナリまたはファイル不在）"
                    self.diffHunks = []
                }
                self.isLoadingDiff = false
            }
        }
    }

    // nonisolated async: awaiting from @MainActor suspends the actor and runs the function on
    // the cooperative thread pool. Cancellation is inherited (same task, not separate child tasks).

    private nonisolated func parseNameStatus(_ data: Data) async -> [DiffFile] {
        guard !Task.isCancelled else { return [] }
        return GitDiffParser.parseNameStatus(data)
    }

    private nonisolated func parseWorkingTreeStatus(_ data: Data) async -> [DiffFile] {
        guard !Task.isCancelled else { return [] }
        return GitDiffParser.parseStatusPorcelain(data)
    }

    private nonisolated func parseDiff(_ output: String) async -> (hunks: [DiffHunk], infoMessage: String?) {
        guard !Task.isCancelled else { return ([], nil) }
        if output.contains("\nBinary files ") || output.hasPrefix("Binary files ")
                    || output.contains("\nGIT binary patch") || output.hasPrefix("GIT binary patch") {
            return ([], "バイナリファイルのため差分を表示できません")
        }
        let hunks = GitDiffParser.parseDiffContent(output)
        if hunks.isEmpty {
            let hasMetadata = output.contains("\nrename from ") || output.contains("\nrename to ")
                || output.contains("\ncopy from ") || output.contains("\ncopy to ")
                || output.contains("\nnew file mode ") || output.contains("\ndeleted file mode ")
                || output.contains("\nnew mode ") || output.contains("\nold mode ")
                || output.contains("\nsimilarity index ")
            return ([], hasMetadata ? "内容変更なし（ファイルモード・名前変更のみ）" : nil)
        }
        return (hunks, nil)
    }
}
