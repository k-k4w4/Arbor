import SwiftUI
import AppKit

private struct DiffCopyButton: View {
    let rawDiff: String
    @State private var copied = false
    @State private var isHovered = false

    var body: some View {
        Image(systemName: copied ? "checkmark" : "doc.on.doc")
            .font(.caption)
            .foregroundStyle(copied ? Color.green : (isHovered ? Color.primary : Color.secondary))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                (isHovered || copied) ? Color.primary.opacity(0.08) : Color.clear,
                in: RoundedRectangle(cornerRadius: 4)
            )
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .onTapGesture {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(rawDiff, forType: .string)
                copied = true
            }
            .task(id: copied) {
                guard copied else { return }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                copied = false
            }
            .help("diff をコピー")
    }
}

private struct SplitDiffToggleButton: View {
    @Environment(AppSettings.self) private var settings
    @State private var isHovered = false

    var body: some View {
        Image(systemName: settings.showSplitDiff ? "rectangle" : "rectangle.split.2x1")
            .font(.caption)
            .foregroundStyle(isHovered ? Color.primary : Color.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                isHovered ? Color.primary.opacity(0.08) : Color.clear,
                in: RoundedRectangle(cornerRadius: 4)
            )
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .onTapGesture { settings.showSplitDiff.toggle() }
            .help(settings.showSplitDiff ? "Unified diff 表示" : "Split diff 表示")
    }
}

private struct FileListToggleButton: View {
    @Environment(AppSettings.self) private var settings
    @State private var isHovered = false

    var body: some View {
        Image(systemName: settings.showFileTree ? "list.bullet" : "list.bullet.indent")
            .font(.caption)
            .foregroundStyle(isHovered ? Color.primary : Color.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                isHovered ? Color.primary.opacity(0.08) : Color.clear,
                in: RoundedRectangle(cornerRadius: 4)
            )
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .onTapGesture { settings.showFileTree.toggle() }
            .help(settings.showFileTree ? "フラットリスト表示" : "ツリー表示")
            .padding(.trailing, 6)
    }
}

private struct DetailTaskKey: Equatable {
    let repositoryID: UUID?
    let commitID: String?
}

struct DetailView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(AppSettings.self) private var settings
    @FocusState private var fileListFocused: Bool

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
                CommitInfoHeader(
                    commit: commit,
                    commitBody: vm.commitBody,
                    showAbsoluteDates: settings.showAbsoluteDates,
                    onJumpToSHA: { sha in appViewModel.commitListVM?.jumpToCommit(sha: sha) }
                )
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
                        VStack(spacing: 0) {
                            fileListHeader
                            Divider()
                            if settings.showFileTree {
                                FileTreeView(files: vm.changedFiles, isFocused: fileListFocused)
                            } else {
                                ChangedFilesList(files: vm.changedFiles, isFocused: fileListFocused)
                            }
                        }
                        .frame(minHeight: 60, idealHeight: 160)
                        .focusable()
                        .focused($fileListFocused)
                        .focusEffectDisabled()
                        .onKeyPress(.upArrow) {
                            appViewModel.detailVM?.selectPreviousFile()
                            return .handled
                        }
                        .onKeyPress(.downArrow) {
                            appViewModel.detailVM?.selectNextFile()
                            return .handled
                        }
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
    private var fileListHeader: some View {
        HStack {
            Spacer()
            FileListToggleButton()
        }
        .frame(height: 24)
        .background(.bar)
    }

    @ViewBuilder
    private func diffArea(vm: DetailViewModel) -> some View {
        ZStack {
            if vm.isLoadingDiff {
                ProgressView()
            } else if let error = vm.errorMessage, vm.diffHunks.isEmpty {
                EmptyStateView(icon: "exclamationmark.triangle", message: error)
            } else if vm.binaryPreviewData != nil || vm.binaryPreviewFileData != nil {
                binaryPreviewArea(vm: vm)
            } else if let info = vm.diffInfoMessage {
                EmptyStateView(icon: "doc.badge.ellipsis", message: info)
            } else if vm.diffHunks.isEmpty {
                EmptyStateView(icon: "doc.text", message: "差分がありません")
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        SplitDiffToggleButton()
                        if let rawDiff = vm.currentRawDiff {
                            DiffCopyButton(rawDiff: rawDiff)
                        }
                    }
                    .padding(.trailing, 6)
                    .frame(height: 24)
                    .background(.bar)
                    Divider()
                    ScrollView {
                        if settings.showSplitDiff {
                            SplitDiffView(hunks: vm.diffHunks)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            UnifiedDiffView(hunks: vm.diffHunks)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func binaryPreviewArea(vm: DetailViewModel) -> some View {
        if let data = vm.binaryPreviewData {
            BinaryImagePreview(data: data, filename: vm.binaryPreviewFilename ?? "")
        } else if let data = vm.binaryPreviewFileData {
            BinaryFilePreview(data: data, filename: vm.binaryPreviewFilename ?? "")
        }
    }
}
