import SwiftUI

struct RootView: View {
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
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
}
