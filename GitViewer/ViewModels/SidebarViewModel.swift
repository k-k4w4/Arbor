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
    private var loadGeneration: Int = 0

    func cancelAll() {
        loadTask?.cancel()
    }

    func scheduleLoad(service: GitService) {
        loadTask?.cancel()
        loadGeneration += 1
        // Capture gen here so a delayed Task always uses the generation it was scheduled with,
        // not the generation at the time the Task body starts executing.
        let gen = loadGeneration
        loadTask = Task { [weak self] in await self?.load(service: service, gen: gen) }
    }

    private func load(service: GitService, gen: Int) async {
        isLoading = true
        errorMessage = nil
        defer {
            // Only clear the spinner for the generation that set it.
            if loadGeneration == gen { isLoading = false }
        }
        do {
            // Both tasks run concurrently via async let.
            // Refs failure is fatal for the sidebar; stash failure is non-critical (empty list).
            async let refsTask = service.listBranches()
            async let stashTask = service.listStashes()
            // CancellationError from refsTask propagates to the outer catch.
            let allRefs = try await refsTask
            guard !Task.isCancelled, loadGeneration == gen else { return }
            // Await stash separately so its errors don't abort the whole load.
            let allStashes: [GitRef]
            do {
                allStashes = try await stashTask
            } catch is CancellationError {
                return
            } catch {
                // Stash errors (e.g. non-standard git configs, hooks) are non-critical.
                allStashes = []
            }
            guard !Task.isCancelled, loadGeneration == gen else { return }

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

            // In detached HEAD state no local branch has isHead=true.
            // Insert a synthetic HEAD ref so the commit list stays functional.
            if !allRefs.contains(where: { $0.isHead }) {
                localBranches.insert(
                    GitRef(name: "HEAD", shortName: "HEAD", sha: "", refType: .localBranch, isHead: true),
                    at: 0
                )
            }

            // Validate and refresh the selected ref against the new list.
            // If the branch was deleted/renamed fall back to HEAD.
            // If it still exists, replace with the fresh instance (updated SHA/isHead).
            let freshRefs = localBranches + remoteBranches + tags + stashes
            if let current = selectedRef {
                if let updated = freshRefs.first(where: { $0.name == current.name }) {
                    selectedRef = updated
                } else {
                    selectedRef = localBranches.first { $0.isHead }
                        ?? localBranches.first
                        ?? remoteBranches.first
                        ?? tags.first
                        ?? stashes.first
                }
            } else {
                selectedRef = localBranches.first { $0.isHead }
                    ?? localBranches.first
                    ?? remoteBranches.first
                    ?? tags.first
                    ?? stashes.first
            }
        } catch is CancellationError {
            return  // defer handles isLoading with generation guard
        } catch {
            guard loadGeneration == gen else { return }
            errorMessage = error.localizedDescription
        }
    }
}
