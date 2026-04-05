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
    // Binary preview state — set when a binary file is selected
    var binaryPreviewData: Data?        // image binary (png/jpg/jpeg/gif/webp)
    var binaryPreviewFileData: Data?    // non-image binary for Quick Look / save
    var binaryPreviewFilename: String?  // display name for the binary file

    private var gitService: GitService?
    private var fileTask: Task<Void, Never>?
    private var diffTask: Task<Void, Never>?
    private var bodyTask: Task<Void, Never>?
    // Monotonically increasing counters. Each load()/selectFile() call increments its
    // counter so tasks can detect if a newer call has superseded them.
    private var fileGeneration: Int = 0
    private var diffGeneration: Int = 0

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
        binaryPreviewData = nil
        binaryPreviewFileData = nil
        binaryPreviewFilename = nil
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
        fileGeneration += 1
        let fileGen = fileGeneration

        if commit.isWorkingTreeSentinel {
            loadWorkingTree(service: service, commitID: commit.id, generation: fileGen)
            return
        }

        fileTask = Task { [weak self] in
            defer {
                // Safety net: if this task exits without resetting isLoadingFiles (e.g. guard
                // fired due to a transient cancellation flag) and no newer load() has run,
                // reset the stuck loading state so the view doesn't spin indefinitely.
                if let s = self, s.fileGeneration == fileGen, s.isLoadingFiles {
                    s.isLoadingFiles = false
                }
            }
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

    private func loadWorkingTree(service: GitService, commitID: String, generation: Int) {
        fileTask = Task { [weak self] in
            defer {
                if let s = self, s.fileGeneration == generation, s.isLoadingFiles {
                    s.isLoadingFiles = false
                }
            }
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

    func selectNextFile() {
        guard !changedFiles.isEmpty else { return }
        guard let current = selectedFile,
              let idx = changedFiles.firstIndex(where: { $0.id == current.id }),
              idx + 1 < changedFiles.count else { return }
        selectFile(changedFiles[idx + 1])
    }

    func selectPreviousFile() {
        guard !changedFiles.isEmpty else { return }
        guard let current = selectedFile,
              let idx = changedFiles.firstIndex(where: { $0.id == current.id }),
              idx > 0 else { return }
        selectFile(changedFiles[idx - 1])
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
        binaryPreviewData = nil
        binaryPreviewFileData = nil
        binaryPreviewFilename = nil
        diffGeneration += 1
        let diffGen = diffGeneration
        diffTask = Task { [weak self] in
            defer {
                if let s = self, s.diffGeneration == diffGen, s.isLoadingDiff {
                    s.isLoadingDiff = false
                }
            }
            do {
                // Untracked files: read from disk and display as all-added lines
                if file.status == .untracked {
                    let content = try await service.fetchUntrackedContent(rawPath: file.rawNewPath)
                    guard let self, !Task.isCancelled, self.selectedFile?.id == fileID else { return }
                    let hunk = DetailViewModel.buildAllAddedHunk(content: content)
                    self.diffHunks = hunk.lines.isEmpty ? [] : [hunk]
                    self.diffInfoMessage = hunk.lines.isEmpty ? "空のファイルです" : nil
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

                guard let self else { return }
                let result = await self.parseDiff(output)
                guard !Task.isCancelled,
                      self.commit?.id == commitID,
                      self.selectedFile?.id == fileID else { return }
                if result.isBinary {
                    await self.loadBinaryPreview(file: file, commitID: commitID, service: service, fileID: fileID)
                    guard !Task.isCancelled, self.commit?.id == commitID, self.selectedFile?.id == fileID else { return }
                }
                let hasBinaryPreview = self.binaryPreviewData != nil || self.binaryPreviewFileData != nil
                self.diffInfoMessage = hasBinaryPreview ? nil : result.infoMessage
                self.diffHunks = result.hunks
                self.isLoadingDiff = false
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.commit?.id == commitID, self.selectedFile?.id == fileID else { return }
                // Both too-large and binary/unreadable: attempt to fetch the file for download.
                let fallbackMessage: String
                if case .outputTooLarge? = error as? GitError {
                    fallbackMessage = "ファイルが大きすぎるため差分を表示できません"
                } else {
                    fallbackMessage = "差分を取得できません（バイナリまたはファイル不在）"
                }
                await self.loadBinaryPreview(file: file, commitID: commitID, service: service, fileID: fileID)
                guard !Task.isCancelled, self.commit?.id == commitID, self.selectedFile?.id == fileID else { return }
                let hasBinaryPreview = self.binaryPreviewData != nil || self.binaryPreviewFileData != nil
                self.diffInfoMessage = hasBinaryPreview ? nil : fallbackMessage
                self.diffHunks = []
                self.isLoadingDiff = false
            }
        }
    }

    // nonisolated async: awaiting from @MainActor suspends the actor and runs the function on
    // the cooperative thread pool. Cancellation is inherited (same task, not separate child tasks).

    private static func buildAllAddedHunk(content: String) -> DiffHunk {
        var lines = content.components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }
        var hunk = DiffHunk(
            header: "@@ -0,0 +1,\(lines.count) @@",
            oldStart: 0, oldCount: 0,
            newStart: 1, newCount: lines.count
        )
        for (i, line) in lines.enumerated() {
            hunk.lines.append(DiffLine(
                hunkIndex: 0, index: i,
                type: .added,
                content: line,
                newLineNumber: i + 1
            ))
        }
        return hunk
    }

    private nonisolated func parseNameStatus(_ data: Data) async -> [DiffFile] {
        guard !Task.isCancelled else { return [] }
        return GitDiffParser.parseNameStatus(data)
    }

    private nonisolated func parseWorkingTreeStatus(_ data: Data) async -> [DiffFile] {
        guard !Task.isCancelled else { return [] }
        return GitDiffParser.parseStatusPorcelain(data)
    }

    // Fetch and store binary preview data for the selected file (committed or working tree).
    // Skips deleted files (no content to fetch).
    // Sets binaryPreviewData for images, binaryPreviewFileData + binaryPreviewFilename for others.
    private func loadBinaryPreview(file: DiffFile, commitID: String, service: GitService, fileID: String) async {
        // Skip deleted files: committed deleted files are gone from the tree;
        // unstaged deleted files no longer exist on disk. Both cases are covered by this guard.
        guard file.status != .deleted else { return }
        guard !Task.isCancelled, commit?.id == commitID, selectedFile?.id == fileID else { return }
        let ext = URL(fileURLWithPath: file.newPath).pathExtension.lowercased()
        do {
            let data: Data
            if let staged = file.staged {
                // Working tree: staged area or disk
                data = staged
                    ? try await service.fetchStagedFileBlob(rawPath: file.rawNewPath)
                    : try await service.fetchWorkingTreeFileBlob(rawPath: file.rawNewPath)
            } else {
                // Committed file
                data = try await service.fetchFileBlob(commit: commitID, rawPath: file.rawNewPath)
            }
            guard !Task.isCancelled, commit?.id == commitID, selectedFile?.id == fileID else { return }
            let name = URL(fileURLWithPath: file.newPath).lastPathComponent
            if ["png", "jpg", "jpeg", "gif", "webp"].contains(ext) {
                binaryPreviewData = data
                binaryPreviewFilename = name
            } else {
                binaryPreviewFileData = data
                binaryPreviewFilename = name
            }
        } catch {
            // Preview fetch failed; diffInfoMessage fallback will be used
        }
    }

    private nonisolated func parseDiff(_ output: String) async -> (hunks: [DiffHunk], infoMessage: String?, isBinary: Bool) {
        guard !Task.isCancelled else { return ([], nil, false) }
        if output.contains("\nBinary files ") || output.hasPrefix("Binary files ")
                    || output.contains("\nGIT binary patch") || output.hasPrefix("GIT binary patch") {
            return ([], "バイナリファイルのため差分を表示できません", true)
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
