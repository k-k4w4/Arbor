import SwiftUI

struct RepositoryCell: View {
    let repository: Repository
    let isSelected: Bool

    @State private var pathExists = true

    var body: some View {
        HStack {
            Label(repository.name, systemImage: "folder")
                .lineLimit(1)
            if !pathExists {
                Spacer()
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                    .help("リポジトリが見つかりません: \(repository.path.path)")
            }
        }
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .task(id: repository.id) {
            pathExists = FileManager.default.fileExists(atPath: repository.path.path)
        }
    }
}
