import SwiftUI

struct RepositoryCell: View {
    let repository: Repository
    let isSelected: Bool

    @State private var pathExists = true

    var body: some View {
        HStack {
            Label(repository.name, systemImage: "folder")
                .lineLimit(1)
            Spacer()
            if !pathExists {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                    .help("リポジトリが見つかりません: \(repository.path.path)")
            }
        }
        .frame(maxWidth: .infinity)
        .task(id: repository.id) {
            pathExists = FileManager.default.fileExists(atPath: repository.path.path)
        }
    }
}
