import SwiftUI
import AppKit

struct SidebarView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(AppSettings.self) private var settings
    @State private var addError: String?
    @State private var isAddHovered = false

    private var repoSelection: Binding<Repository.ID?> {
        Binding(
            get: { appViewModel.selectedRepository?.id },
            set: { id in
                guard let id, let repo = appViewModel.repositories.first(where: { $0.id == id }) else { return }
                appViewModel.selectRepository(repo)
            }
        )
    }

    private var refSelection: Binding<GitRef.ID?> {
        Binding(
            get: { appViewModel.sidebarVM?.selectedRef?.id },
            set: { id in
                guard let id, let vm = appViewModel.sidebarVM else { return }
                let allRefs = vm.localBranches + vm.remoteBranches + vm.tags + vm.stashes
                guard let ref = allRefs.first(where: { $0.id == id }) else { return }
                vm.selectedRef = ref
            }
        )
    }

    var body: some View {
        VSplitView {
            List(selection: repoSelection) {
                RepositoryListSection(
                    isCollapsed: settings.isRepositoriesCollapsed,
                    onToggle: { settings.isRepositoriesCollapsed.toggle() }
                )
                Section {
                    if let err = addError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .listRowSeparator(.hidden)
                    }
                    Button {
                        addError = nil
                        openFolder()
                    } label: {
                        Label("リポジトリを追加", systemImage: "plus")
                            .foregroundStyle(isAddHovered ? Color.primary : Color.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                isAddHovered ? Color.primary.opacity(0.08) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 4)
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { isAddHovered = $0 }
                }
            }
            .listStyle(.sidebar)
            .frame(minHeight: 80)

            List(selection: refSelection) {
                if let vm = appViewModel.sidebarVM {
                    if !vm.localBranches.isEmpty {
                        BranchListSection(
                            title: "BRANCHES",
                            refs: vm.localBranches,
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
            .frame(minHeight: 100)
            .overlay {
                if appViewModel.sidebarVM?.isLoading == true {
                    ProgressView()
                }
            }
        }
    }

    private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Gitリポジトリのフォルダを選択してください"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { @MainActor in
            do {
                try await appViewModel.addRepository(at: url)
            } catch {
                addError = error.localizedDescription
            }
        }
    }
}
