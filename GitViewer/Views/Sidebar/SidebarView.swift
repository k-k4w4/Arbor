import SwiftUI

struct SidebarView: View {
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        List {
            RepositoryListSection()
            if let vm = appViewModel.sidebarVM {
                if !vm.localBranches.isEmpty {
                    BranchListSection(title: "BRANCHES", refs: vm.localBranches, sidebarVM: vm)
                }
                if !vm.remoteBranches.isEmpty {
                    BranchListSection(title: "REMOTES", refs: vm.remoteBranches, sidebarVM: vm)
                }
                if !vm.tags.isEmpty {
                    BranchListSection(title: "TAGS", refs: vm.tags, sidebarVM: vm)
                }
                if !vm.stashes.isEmpty {
                    BranchListSection(title: "STASHES", refs: vm.stashes, sidebarVM: vm)
                }
                if let error = vm.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if appViewModel.sidebarVM?.isLoading == true {
                ProgressView()
            }
        }
    }
}
