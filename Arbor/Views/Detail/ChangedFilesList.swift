import SwiftUI

struct ChangedFilesList: View {
    @Environment(AppViewModel.self) private var appViewModel
    let files: [DiffFile]
    var isFocused: Bool = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(files) { file in
                    fileRow(file)
                }
            }
        }
    }

    @ViewBuilder
    private func fileRow(_ file: DiffFile) -> some View {
        let isSelected = appViewModel.detailVM?.selectedFile?.id == file.id
        let rowBg: Color = isSelected
            ? (isFocused
                ? Color(NSColor.selectedContentBackgroundColor)
                : Color(NSColor.unemphasizedSelectedContentBackgroundColor))
            : Color.clear
        let textFg: Color = (isSelected && isFocused) ? Color(NSColor.selectedMenuItemTextColor) : .primary
        HStack(spacing: 6) {
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
