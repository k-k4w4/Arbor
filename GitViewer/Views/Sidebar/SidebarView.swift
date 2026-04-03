import SwiftUI

struct SidebarView: View {
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        List {
            RepositoryListSection()
            if let vm = appViewModel.sidebarVM {
                if !vm.localBranches.isEmpty {
                    BranchListSection(title: "BRANCHES", refs: vm.localBranches, sidebarVM: vm, limit: vm.localBranchesLimit) {
                        vm.localBranchesLimit += SidebarViewModel.pageSize
                    }
                }
                if !vm.remoteBranches.isEmpty {
                    BranchListSection(title: "REMOTES", refs: vm.remoteBranches, sidebarVM: vm, limit: vm.remoteBranchesLimit) {
                        vm.remoteBranchesLimit += SidebarViewModel.pageSize
                    }
                }
                if !vm.tags.isEmpty {
                    BranchListSection(title: "TAGS", refs: vm.tags, sidebarVM: vm, limit: vm.tagsLimit) {
                        vm.tagsLimit += SidebarViewModel.pageSize
                    }
                }
                if !vm.stashes.isEmpty {
                    BranchListSection(title: "STASHES", refs: vm.stashes, sidebarVM: vm, limit: .max) { }
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
