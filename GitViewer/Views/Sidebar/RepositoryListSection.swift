import SwiftUI
import AppKit

private let rowInsets = EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)

struct RepositoryListSection: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var addError: String?

    var body: some View {
        Section {
            ForEach(appViewModel.repositories) { repo in
                let isSelected = appViewModel.selectedRepository?.id == repo.id
                RepositoryCell(repository: repo, isSelected: isSelected)
                    .padding(rowInsets)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        addError = nil
                        appViewModel.selectRepository(repo)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                    .contextMenu {
                        Button("削除", role: .destructive) {
                            addError = nil
                            appViewModel.removeRepository(repo)
                        }
                    }
            }
            if let err = addError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .listRowSeparator(.hidden)
            }
            Button {
                addError = nil
                openFolder()
            } label: {
                Label("リポジトリを追加", systemImage: "plus")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        } header: {
            // Right side reserved for future show/hide toggle
            Text("REPOSITORIES")
        }
    }

    private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Gitリポジトリのフォルダを選択してください"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do {
                try await appViewModel.addRepository(at: url)
            } catch {
                addError = error.localizedDescription
            }
        }
    }
}
