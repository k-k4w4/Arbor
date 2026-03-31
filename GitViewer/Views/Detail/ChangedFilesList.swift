import SwiftUI

struct ChangedFilesList: View {
    @Environment(AppViewModel.self) private var appViewModel
    let files: [DiffFile]

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
        HStack(spacing: 6) {
            FileStatusBadge(status: file.status)
            Text(file.displayPath)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            appViewModel.detailVM?.selectFile(file)
        }
    }
}
