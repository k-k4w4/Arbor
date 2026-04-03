import SwiftUI

private struct DetailTaskKey: Equatable {
    let repositoryID: UUID?
    let commitID: String?
}

struct DetailView: View {
    @Environment(AppViewModel.self) private var appViewModel

    private var taskKey: DetailTaskKey {
        DetailTaskKey(
            repositoryID: appViewModel.selectedRepository?.id,
            commitID: appViewModel.commitListVM?.selectedCommit?.id
        )
    }

    var body: some View {
        contentView
            .task(id: taskKey) {
                guard
                    let commit = appViewModel.commitListVM?.selectedCommit,
                    let service = appViewModel.gitService,
                    let vm = appViewModel.detailVM
                else {
                    // Selection cleared — reset detail pane so stale data doesn't linger.
                    appViewModel.detailVM?.clear()
                    return
                }
                vm.load(commit: commit, service: service)
            }
    }

    @ViewBuilder
    private var contentView: some View {
        if let vm = appViewModel.detailVM, let commit = vm.commit {
            VStack(spacing: 0) {
                CommitInfoHeader(commit: commit, commitBody: vm.commitBody, showAbsoluteDates: appViewModel.showAbsoluteDates)
                Divider()
                if vm.isLoadingFiles {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = vm.errorMessage, vm.changedFiles.isEmpty {
                    EmptyStateView(icon: "exclamationmark.triangle", message: error)
                } else if vm.changedFiles.isEmpty {
                    EmptyStateView(icon: "doc", message: "変更ファイルがありません")
                } else {
                    VSplitView {
                        ChangedFilesList(files: vm.changedFiles)
                            .frame(minHeight: 60, idealHeight: 160)
                        diffArea(vm: vm)
                            .frame(minHeight: 80)
                    }
                }
            }
        } else {
            EmptyStateView(
                icon: "cursorarrow.click",
                message: "コミットを選択してください"
            )
        }
    }

    @ViewBuilder
    private func diffArea(vm: DetailViewModel) -> some View {
        ZStack {
            if vm.isLoadingDiff {
                ProgressView()
            } else if let error = vm.errorMessage, vm.diffHunks.isEmpty {
                EmptyStateView(icon: "exclamationmark.triangle", message: error)
            } else if let info = vm.diffInfoMessage {
                EmptyStateView(icon: "doc.badge.ellipsis", message: info)
            } else if vm.diffHunks.isEmpty {
                EmptyStateView(icon: "doc.text", message: "差分がありません")
            } else {
                ScrollView {
                    UnifiedDiffView(hunks: vm.diffHunks)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
