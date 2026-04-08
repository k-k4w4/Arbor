import SwiftUI

private struct FileTreeNode: Identifiable {
    let id: String
    let name: String
    let file: DiffFile?
    let children: [FileTreeNode]

    var isDirectory: Bool { file == nil }
}

private struct VisibleRow: Identifiable {
    let id: String
    let node: FileTreeNode
    let depth: Int
}

struct FileTreeView: View {
    @Environment(AppViewModel.self) private var appViewModel
    let files: [DiffFile]
    var isFocused: Bool = false

    @State private var collapsed: Set<String> = []

    private var roots: [FileTreeNode] {
        Self.buildTree(files: files, pathPrefix: "")
    }

    private var visibleRows: [VisibleRow] {
        var result: [VisibleRow] = []
        for node in roots {
            appendRows(node: node, depth: 0, to: &result)
        }
        return result
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(visibleRows) { row in
                    if row.node.isDirectory {
                        directoryRow(row.node, depth: row.depth)
                    } else {
                        fileRow(row.node, depth: row.depth)
                    }
                }
            }
        }
    }

    private func appendRows(node: FileTreeNode, depth: Int, to result: inout [VisibleRow]) {
        result.append(VisibleRow(id: node.id, node: node, depth: depth))
        if node.isDirectory && !collapsed.contains(node.id) {
            for child in node.children {
                appendRows(node: child, depth: depth + 1, to: &result)
            }
        }
    }

    @ViewBuilder
    private func directoryRow(_ node: FileTreeNode, depth: Int) -> some View {
        HStack(spacing: 4) {
            Color.clear.frame(width: CGFloat(depth) * 12)
            Image(systemName: collapsed.contains(node.id) ? "chevron.right" : "chevron.down")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 10)
            Image(systemName: "folder")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(node.name)
                .font(.caption)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if collapsed.contains(node.id) {
                collapsed.remove(node.id)
            } else {
                collapsed.insert(node.id)
            }
        }
    }

    @ViewBuilder
    private func fileRow(_ node: FileTreeNode, depth: Int) -> some View {
        // Invariant: non-directory nodes always have a non-nil file (enforced by buildTree).
        if let file = node.file {
            let isSelected = appViewModel.detailVM?.selectedFile?.id == file.id
            let rowBg: Color = isSelected
                ? (isFocused
                    ? Color(NSColor.selectedContentBackgroundColor)
                    : Color(NSColor.unemphasizedSelectedContentBackgroundColor))
                : Color.clear
            let textFg: Color = (isSelected && isFocused) ? Color(NSColor.selectedMenuItemTextColor) : .primary
            HStack(spacing: 4) {
                // depth indent + chevron alignment offset (10 chevron + 4 spacing = 14)
                Color.clear.frame(width: CGFloat(depth) * 12 + 14)
                FileStatusBadge(status: file.status)
                if let staged = file.staged {
                    Text(staged ? "S" : "U")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 20)
                        .padding(.vertical, 2)
                        .background(
                            staged ? Color.blue.opacity(0.8) : Color.orange.opacity(0.9),
                            in: RoundedRectangle(cornerRadius: 3)
                        )
                }
                Text(node.name)
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
                appViewModel.detailVM?.selectFile(file)
            }
            .contextMenu {
                Button("パスをコピー") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(file.newPath, forType: .string)
                }
            }
        }
    }

    private static func buildTree(files: [DiffFile], pathPrefix: String) -> [FileTreeNode] {
        var dirMap: [String: [DiffFile]] = [:]
        var leafFiles: [DiffFile] = []

        for file in files {
            let relativePath: String
            if pathPrefix.isEmpty {
                relativePath = file.newPath
            } else {
                guard file.newPath.hasPrefix(pathPrefix) else { continue }
                relativePath = String(file.newPath.dropFirst(pathPrefix.count))
            }

            if let slashRange = relativePath.range(of: "/") {
                let dirName = String(relativePath[..<slashRange.lowerBound])
                dirMap[dirName, default: []].append(file)
            } else {
                leafFiles.append(file)
            }
        }

        var nodes: [FileTreeNode] = []

        for dir in dirMap.keys.sorted() {
            let newPrefix = pathPrefix + dir + "/"
            let children = buildTree(files: dirMap[dir] ?? [], pathPrefix: newPrefix)
            nodes.append(FileTreeNode(id: "dir:\(newPrefix)", name: dir, file: nil, children: children))
        }

        for file in leafFiles.sorted(by: { $0.newPath < $1.newPath }) {
            let filename = URL(fileURLWithPath: file.newPath).lastPathComponent
            nodes.append(FileTreeNode(
                id: file.id,
                name: filename.isEmpty ? file.displayPath : filename,
                file: file,
                children: []
            ))
        }

        return nodes
    }
}
