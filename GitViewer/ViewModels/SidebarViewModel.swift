import Foundation
import Observation

@MainActor
@Observable
final class SidebarViewModel {
    var localBranches: [GitRef] = []
    var remoteBranches: [GitRef] = []
    var tags: [GitRef] = []
    var stashes: [GitRef] = []
    var selectedRef: GitRef?
    var isLoading: Bool = false
    var errorMessage: String?

    private var loadTask: Task<Void, Never>?

    func cancelAll() {
        loadTask?.cancel()
    }

    func scheduleLoad(service: GitService) {
        loadTask?.cancel()
        loadTask = Task { await self.load(service: service) }
    }

    private func load(service: GitService) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let refsTask = service.listBranches()
            async let stashTask = service.listStashes()
            let (allRefs, allStashes) = try await (refsTask, stashTask)

            localBranches = allRefs.filter {
                if case .localBranch = $0.refType { return true }
                return false
            }
            remoteBranches = allRefs.filter {
                if case .remoteBranch = $0.refType { return true }
                return false
            }
            tags = allRefs.filter {
                if case .tag = $0.refType { return true }
                return false
            }
            stashes = allStashes

            if selectedRef == nil {
                selectedRef = localBranches.first { $0.isHead } ?? localBranches.first
            }
        } catch is CancellationError {
            return  // defer resets isLoading = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
