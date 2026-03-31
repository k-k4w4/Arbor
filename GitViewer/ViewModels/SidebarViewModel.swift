import Foundation
import Observation

// Phase 2: Sidebar state
@MainActor
@Observable
final class SidebarViewModel {
    var localBranches: [GitRef] = []
    var remoteBranches: [GitRef] = []
    var tags: [GitRef] = []
    var stashes: [GitRef] = []
    var selectedRef: GitRef?
    var isLoading: Bool = false
}
