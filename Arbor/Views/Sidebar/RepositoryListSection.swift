import SwiftUI

struct RepositoryListSection: View {
    @Environment(AppViewModel.self) private var appViewModel
    let isCollapsed: Bool
    let onToggle: () -> Void

    var body: some View {
        Section {
            if !isCollapsed {
                ForEach(appViewModel.repositories) { repo in
                    RepositoryCell(repository: repo)
                        .tag(repo.id)
                        .contextMenu {
                            let repos = appViewModel.repositories
                            if repos.first?.id != repo.id {
                                Button("上に移動") { appViewModel.moveRepositoryUp(repo) }
                            }
                            if repos.last?.id != repo.id {
                                Button("下に移動") { appViewModel.moveRepositoryDown(repo) }
                            }
                            Divider()
                            Button("削除", role: .destructive) {
                                appViewModel.removeRepository(repo)
                            }
                        }
                }
                .onMove { source, dest in
                    appViewModel.moveRepositories(from: source, to: dest)
                }
            }
        } header: {
            SectionToggleHeader(title: "REPOSITORIES", isCollapsed: isCollapsed, onToggle: onToggle)
        }
    }
}
