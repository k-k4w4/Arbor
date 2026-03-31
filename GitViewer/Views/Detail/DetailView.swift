import SwiftUI

private struct DetailTaskKey: Equatable {
    let commitID: String?
}

struct DetailView: View {
    @Environment(AppViewModel.self) private var appViewModel

    private var taskKey: DetailTaskKey {
        DetailTaskKey(commitID: appViewModel.commitListVM?.selectedCommit?.id)
    }

    var body: some View {
        contentView
            .task(id: taskKey) {
                guard
                    let commit = appViewModel.commitListVM?.selectedCommit,
                    let service = appViewModel.gitService,
                    let vm = appViewModel.detailVM
                else { return }
                vm.load(commit: commit, service: service)
            }
    }

    @ViewBuilder
    private var contentView: some View {
        if let vm = appViewModel.detailVM, let commit = vm.commit {
            VStack(spacing: 0) {
                CommitInfoHeader(commit: commit)
                Divider()
                if vm.isLoadingFiles {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.changedFiles.isEmpty {
                    EmptyStateView(icon: "doc", message: "変更ファイルがありません")
                } else {
                    ChangedFilesList(files: vm.changedFiles)
                        .frame(maxHeight: 160)
                    Divider()
                    diffArea(vm: vm)
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
        if vm.isLoadingDiff {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.diffHunks.isEmpty {
            EmptyStateView(icon: "doc.text", message: "差分がありません")
        } else {
            ScrollView(.vertical) {
                UnifiedDiffView(hunks: vm.diffHunks, wrapLines: vm.wrapLines)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
