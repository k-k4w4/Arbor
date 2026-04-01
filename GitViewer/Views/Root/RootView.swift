import SwiftUI

struct RootView: View {
    @Environment(AppViewModel.self) private var appViewModel

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
                    DetailView()
                        .navigationSplitViewColumnWidth(min: 280, ideal: 360)
                }
                .navigationSplitViewStyle(.balanced)
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
