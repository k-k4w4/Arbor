import SwiftUI
import AppKit

struct CommitListView: View {
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        contentView
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    if let ref = appViewModel.sidebarVM?.selectedRef {
                        Label(ref.shortName, systemImage: "arrow.triangle.branch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        appViewModel.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("リフレッシュ (⌘R)")
                }
            }
    }

    @ViewBuilder
    private var contentView: some View {
        if let vm = appViewModel.commitListVM {
            commitList(vm: vm)
        } else {
            EmptyStateView(icon: "arrow.triangle.branch", message: "リポジトリを選択してください")
        }
    }

    @ViewBuilder
    private func commitList(vm: CommitListViewModel) -> some View {
        VStack(spacing: 0) {
            if let error = vm.errorMessage, vm.filteredCommits.isEmpty && !vm.isLoading {
                EmptyStateView(icon: "exclamationmark.triangle", message: error)
            } else if vm.filteredCommits.isEmpty && !vm.isLoading {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    message: vm.searchQuery.isEmpty ? "コミットがありません" : "一致するコミットがありません"
                )
            } else {
                List(vm.filteredCommits, selection: Binding(
                    get: { vm.selectedCommit?.id },
                    set: { id in vm.selectedCommit = vm.filteredCommits.first { $0.id == id } }
                )) { commit in
                    CommitRow(commit: commit)
                        .tag(commit.id)
                        .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                        .contextMenu {
                            Button("SHAをコピー") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(commit.id, forType: .string)
                            }
                            Divider()
                            Button("Finderで表示") {
                                if let repoPath = appViewModel.selectedRepository?.path.path {
                                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: repoPath)
                                }
                            }
                        }
                        .onAppear {
                            // Only page-load when not searching; filtered results reach
                            // the bottom quickly and would trigger unbounded loading.
                            if commit.id == vm.filteredCommits.last?.id && vm.searchQuery.isEmpty {
                                vm.loadMore()
                            }
                        }
                }
                .listStyle(.plain)
            }
            if vm.isLoading {
                ProgressView().padding(8)
            }
        }
        .searchable(
            text: Binding(get: { vm.searchQuery }, set: { vm.updateSearch($0) }),
            prompt: "コミットを検索"
        )
    }
}
