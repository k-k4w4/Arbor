import SwiftUI

struct SidebarView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(AppSettings.self) private var settings

    var body: some View {
        List {
            RepositoryListSection(
                isCollapsed: settings.isRepositoriesCollapsed,
                onToggle: { settings.isRepositoriesCollapsed.toggle() }
            )
            if let vm = appViewModel.sidebarVM {
                if !vm.localBranches.isEmpty {
                    BranchListSection(
                        title: "BRANCHES",
                        refs: vm.localBranches,
                        sidebarVM: vm,
                        limit: vm.localBranchesLimit,
                        isCollapsed: settings.isBranchesCollapsed,
                        onToggle: { settings.isBranchesCollapsed.toggle() }
                    ) {
                        vm.localBranchesLimit += SidebarViewModel.pageSize
                    }
                }
                if !vm.remoteBranches.isEmpty {
                    BranchListSection(
                        title: "REMOTES",
                        refs: vm.remoteBranches,
                        sidebarVM: vm,
                        limit: vm.remoteBranchesLimit,
                        isCollapsed: settings.isRemotesCollapsed,
                        onToggle: { settings.isRemotesCollapsed.toggle() }
                    ) {
                        vm.remoteBranchesLimit += SidebarViewModel.pageSize
                    }
                }
                if !vm.tags.isEmpty {
                    BranchListSection(
                        title: "TAGS",
                        refs: vm.tags,
                        sidebarVM: vm,
                        limit: vm.tagsLimit,
                        isCollapsed: settings.isTagsCollapsed,
                        onToggle: { settings.isTagsCollapsed.toggle() }
                    ) {
                        vm.tagsLimit += SidebarViewModel.pageSize
                    }
                }
                if !vm.stashes.isEmpty {
                    BranchListSection(
                        title: "STASHES",
                        refs: vm.stashes,
                        sidebarVM: vm,
                        limit: .max,
                        isCollapsed: settings.isStashesCollapsed,
                        onToggle: { settings.isStashesCollapsed.toggle() }
                    ) { }
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
