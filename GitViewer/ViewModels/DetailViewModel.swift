import Foundation
import Observation

@MainActor
@Observable
final class DetailViewModel {
    var commit: Commit?
    var changedFiles: [DiffFile] = []
    var selectedFile: DiffFile?
    var diffHunks: [DiffHunk] = []
    var isLoadingFiles: Bool = false
    var isLoadingDiff: Bool = false
    var errorMessage: String?
    var wrapLines: Bool = false

    private var gitService: GitService?
    private var fileTask: Task<Void, Never>?
    private var diffTask: Task<Void, Never>?

    func cancelAll() {
        fileTask?.cancel()
        diffTask?.cancel()
    }

    func load(commit: Commit, service: GitService) {
        fileTask?.cancel()
        diffTask?.cancel()
        self.commit = commit
        self.gitService = service
        changedFiles = []
        selectedFile = nil
        diffHunks = []
        isLoadingFiles = true
        isLoadingDiff = false
        errorMessage = nil
        fileTask = Task {
            do {
                let output = try await service.fetchDiff(commit: commit.id)
                guard !Task.isCancelled else {
                    self.isLoadingFiles = false
                    return
                }
                let files = GitDiffParser.parseNameStatus(output)
                self.changedFiles = files
                self.isLoadingFiles = false
                if let first = files.first {
                    self.selectFile(first)
                }
            } catch is CancellationError {
                self.isLoadingFiles = false
            } catch {
                self.isLoadingFiles = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func selectFile(_ file: DiffFile) {
        guard let service = gitService, let commit = commit else { return }
        diffTask?.cancel()
        selectedFile = file
        diffHunks = []
        isLoadingDiff = true
        diffTask = Task {
            do {
                let output = try await service.fetchDiffContent(commit: commit.id, file: file.newPath)
                guard !Task.isCancelled else {
                    self.isLoadingDiff = false
                    return
                }
                self.diffHunks = GitDiffParser.parseDiffContent(output)
                self.isLoadingDiff = false
            } catch is CancellationError {
                self.isLoadingDiff = false
            } catch {
                self.isLoadingDiff = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
