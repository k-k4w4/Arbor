import SwiftUI

struct WelcomeView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var isTargeted = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.dashed")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("リポジトリをドロップしてください")
                .font(.title3)
                .foregroundStyle(.secondary)

            Button("フォルダを開く") {
                openFolder()
            }
            .buttonStyle(.borderedProminent)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            addRepository(at: url)
            return true
        } isTargeted: { isTargeted = $0 }
    }

    private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Gitリポジトリのフォルダを選択してください"

        if panel.runModal() == .OK, let url = panel.url {
            addRepository(at: url)
        }
    }

    private func addRepository(at url: URL) {
        errorMessage = nil
        Task {
            do {
                try await appViewModel.addRepository(at: url)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
