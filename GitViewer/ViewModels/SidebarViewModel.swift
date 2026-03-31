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

    func load(service: GitService) async {
        isLoading = true
        errorMessage = nil
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
            // silently discard result when task was superseded
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
