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
