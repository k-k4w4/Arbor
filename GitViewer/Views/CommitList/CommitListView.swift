import SwiftUI

private struct CommitTaskKey: Equatable {
    let vmInstanceID: UUID
    let selectedRef: GitRef?
}

struct CommitListView: View {
    @Environment(AppViewModel.self) private var appViewModel

    private var taskKey: CommitTaskKey {
        CommitTaskKey(
            vmInstanceID: appViewModel.commitListVM?.instanceID ?? UUID(),
            selectedRef: appViewModel.sidebarVM?.selectedRef
        )
    }

    var body: some View {
        contentView
            .task(id: taskKey) {
                guard
                    let ref = appViewModel.sidebarVM?.selectedRef,
                    let service = appViewModel.gitService,
                    let vm = appViewModel.commitListVM
                else { return }
                vm.loadInitial(ref: ref.gitRef, service: service)
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
            if vm.filteredCommits.isEmpty && !vm.isLoading {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    message: vm.searchQuery.isEmpty ? "コミットがありません" : "一致するコミットがありません"
                )
            } else {
                List(vm.filteredCommits) { commit in
                    CommitRow(commit: commit)
                        .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                        .listRowBackground(
                            vm.selectedCommit?.id == commit.id
                                ? Color.accentColor.opacity(0.12)
                                : Color.clear
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            vm.selectedCommit = commit
                        }
                        .onAppear {
                            if commit.id == vm.filteredCommits.last?.id {
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
