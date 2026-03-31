import SwiftUI

struct RepositoryCell: View {
    let repository: Repository
    let isSelected: Bool

    var body: some View {
        Label(repository.name, systemImage: "folder")
            .lineLimit(1)
            .listRowBackground(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
    }
}
