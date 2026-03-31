import SwiftUI

struct RepositoryListSection: View {
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        Section("REPOSITORIES") {
            ForEach(appViewModel.repositories) { repo in
                RepositoryCell(repository: repo,
                               isSelected: appViewModel.selectedRepository?.id == repo.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appViewModel.selectRepository(repo)
                    }
            }
        }
    }
}
