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

    func selectFile(_ file: DiffFile) {
        guard let service = gitService, let commit = commit else { return }
        // Capture both IDs: file.id alone is status+path which can match across different commits.
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
                let output = try await service.fetchDiffContent(commit: commitID, rawPath: file.rawNewPath)
                // Verify both the selected file and the active commit are unchanged.
                guard let self, !Task.isCancelled,
                      self.commit?.id == commitID,
                      self.selectedFile?.id == fileID else { return }
                // Parse the diff on a background thread (nonisolated child task inherits cancellation).
                let result = await parseDiff(output)
                guard !Task.isCancelled,
                      self.commit?.id == commitID,
                      self.selectedFile?.id == fileID else { return }
                self.diffInfoMessage = result.infoMessage
                self.diffHunks = result.hunks
                self.isLoadingDiff = false
            } catch is CancellationError {
                // clear() or the next selectFile() manages isLoadingDiff; don't overwrite here.
                return
            } catch {
                guard let self, self.commit?.id == commitID, self.selectedFile?.id == fileID else { return }
                // outputTooLarge is an expected condition, not an error to show in UI.
                if case .outputTooLarge? = error as? GitError {
                    self.diffInfoMessage = "ファイルが大きすぎるため差分を表示できません"
                    self.diffHunks = []
                } else {
                    self.errorMessage = error.localizedDescription
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
