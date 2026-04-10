import SwiftUI
import AppKit

struct CompareView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(AppSettings.self) private var settings
    @FocusState private var fileListFocused: Bool

    var body: some View {
        if let vm = appViewModel.compareVM, let sidebar = appViewModel.sidebarVM {
            VStack(spacing: 0) {
                refPickerHeader(vm: vm, sidebar: sidebar)
                Divider()
                if vm.isLoadingFiles {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = vm.errorMessage, vm.changedFiles.isEmpty {
                    EmptyStateView(icon: "exclamationmark.triangle", message: error)
                } else if vm.baseRef != nil && vm.targetRef != nil && vm.changedFiles.isEmpty {
                    EmptyStateView(icon: "checkmark.circle", message: "差分がありません")
                } else if vm.changedFiles.isEmpty {
                    EmptyStateView(icon: "arrow.triangle.branch", message: "比較するブランチを選択してください")
                } else {
                    VSplitView {
                        VStack(spacing: 0) {
                            compareFileListHeader(vm: vm)
                            Divider()
                            compareFileList(vm: vm)
                        }
                        .frame(minHeight: 60, idealHeight: 160)
                        .focusable()
                        .focused($fileListFocused)
                        .focusEffectDisabled()
                        .onKeyPress(.upArrow) {
                            vm.selectPreviousFile()
                            return .handled
                        }
                        .onKeyPress(.downArrow) {
                            vm.selectNextFile()
                            return .handled
                        }
                        compareDiffArea(vm: vm)
                            .frame(minHeight: 80)
                    }
                }
            }
        } else {
            EmptyStateView(icon: "arrow.triangle.branch", message: "比較するブランチを選択してください")
        }
    }

    @ViewBuilder
    private func refPickerHeader(vm: CompareViewModel, sidebar: SidebarViewModel) -> some View {
        HStack(spacing: 8) {
            Picker("Base", selection: Binding(
                get: { vm.baseRef },
                set: { newRef in
                    vm.baseRef = newRef
                    triggerCompare(vm: vm)
                }
            )) {
                Text("ベース").tag(nil as GitRef?)
                refPickerSections(sidebar: sidebar)
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)

            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)

            Picker("Target", selection: Binding(
                get: { vm.targetRef },
                set: { newRef in
                    vm.targetRef = newRef
                    triggerCompare(vm: vm)
                }
            )) {
                Text("ターゲット").tag(nil as GitRef?)
                refPickerSections(sidebar: sidebar)
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)

            Button {
                let oldBase = vm.baseRef
                vm.baseRef = vm.targetRef
                vm.targetRef = oldBase
                triggerCompare(vm: vm)
            } label: {
                Image(systemName: "arrow.left.arrow.right")
            }
            .help("ベースとターゲットを入れ替え")
            .disabled(vm.baseRef == nil && vm.targetRef == nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    @ViewBuilder
    private func refPickerSections(sidebar: SidebarViewModel) -> some View {
        if !sidebar.localBranches.isEmpty {
            Section("ローカル") {
                ForEach(sidebar.localBranches) { ref in
                    Text(ref.shortName).tag(ref as GitRef?)
                }
            }
        }
        if !sidebar.remoteBranches.isEmpty {
            Section("リモート") {
                ForEach(sidebar.remoteBranches) { ref in
                    refLabel(ref).tag(ref as GitRef?)
                }
            }
        }
        if !sidebar.tags.isEmpty {
            Section("タグ") {
                ForEach(sidebar.tags) { ref in
                    Text(ref.shortName).tag(ref as GitRef?)
                }
            }
        }
    }

    private func refLabel(_ ref: GitRef) -> Text {
        if case .remoteBranch(let remote) = ref.refType {
            return Text("\(remote)/\(ref.shortName)")
        }
        return Text(ref.shortName)
    }

    private func triggerCompare(vm: CompareViewModel) {
        guard let base = vm.baseRef, let target = vm.targetRef,
              let service = appViewModel.gitService else { return }
        vm.load(baseRef: base, targetRef: target, service: service)
    }

    @ViewBuilder
    private func compareFileListHeader(vm: CompareViewModel) -> some View {
        HStack {
            if let stat = vm.diffStat {
                let lines = stat.components(separatedBy: "\n")
                if let summary = lines.last(where: { $0.contains("file") }) {
                    Text(summary.trimmingCharacters(in: .whitespaces))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(.bar)
    }

    @ViewBuilder
    private func compareFileList(vm: CompareViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(vm.changedFiles) { file in
                    compareFileRow(file, vm: vm)
                }
            }
        }
    }

    @ViewBuilder
    private func compareFileRow(_ file: DiffFile, vm: CompareViewModel) -> some View {
        let isSelected = vm.selectedFile?.id == file.id
        let rowBg: Color = isSelected
            ? (fileListFocused
                ? Color(NSColor.selectedContentBackgroundColor)
                : Color(NSColor.unemphasizedSelectedContentBackgroundColor))
            : Color.clear
        let textFg: Color = (isSelected && fileListFocused)
            ? Color(NSColor.selectedMenuItemTextColor) : .primary
        HStack(spacing: 6) {
            FileStatusBadge(status: file.status)
            Text(file.displayPath)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(textFg)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(rowBg)
        .contentShape(Rectangle())
        .onTapGesture {
            vm.selectFile(file)
        }
        .contextMenu {
            Button("パスをコピー") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(file.newPath, forType: .string)
            }
        }
    }

    @ViewBuilder
    private func compareDiffArea(vm: CompareViewModel) -> some View {
        ZStack {
            if vm.isLoadingDiff {
                ProgressView()
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
                        let lang = vm.selectedFile.flatMap { SyntaxHighlightService.language(for: $0.newPath) }
                        if settings.showSplitDiff {
                            SplitDiffView(hunks: vm.diffHunks, language: lang)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            UnifiedDiffView(hunks: vm.diffHunks, language: lang)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
