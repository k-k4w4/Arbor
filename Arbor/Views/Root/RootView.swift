import SwiftUI

struct RootView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var isDropTargeted = false

    var body: some View {
        Group {
            if appViewModel.repositories.isEmpty {
                WelcomeView()
            } else {
                NavigationSplitView {
                    SidebarView()
                        .navigationSplitViewColumnWidth(min: 180, ideal: 240)
                } content: {
                    CommitListView()
                        .navigationSplitViewColumnWidth(min: 320, ideal: 500)
                } detail: {
                    if appViewModel.isCompareMode {
                        CompareView()
                            .navigationSplitViewColumnWidth(min: 280, ideal: 360)
                    } else {
                        DetailView()
                            .navigationSplitViewColumnWidth(min: 280, ideal: 360)
                    }
                }
                .navigationSplitViewStyle(.balanced)
                .dropDestination(for: URL.self) { urls, _ in
                    guard let url = urls.first else { return false }
                    isDropTargeted = false
                    Task { @MainActor in
                        do {
                            try await appViewModel.addRepository(at: url)
                        } catch {
                            appViewModel.errorMessage = error.localizedDescription
                        }
                    }
                    return true
                } isTargeted: { isDropTargeted = $0 }
                .overlay {
                    if isDropTargeted {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.accentColor, lineWidth: 2)
                            .background(Color.accentColor.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .navigationTitle(appViewModel.windowTitle)
        .alert(
            "エラー",
            isPresented: Binding(
                get: { appViewModel.errorMessage != nil },
                set: { if !$0 { appViewModel.errorMessage = nil } }
            )
        ) {
            Button("OK") { appViewModel.errorMessage = nil }
        } message: {
            Text(appViewModel.errorMessage ?? "")
        }
    }
}
