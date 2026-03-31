import Foundation
import Observation

// Phase 4: Commit detail state
@MainActor
@Observable
final class DetailViewModel {
    var commit: Commit?
    var changedFiles: [DiffFile] = []
    var selectedFile: DiffFile?
    var diffHunks: [DiffHunk] = []
    var isLoadingFiles: Bool = false
    var isLoadingDiff: Bool = false
    var wrapLines: Bool = false
}
