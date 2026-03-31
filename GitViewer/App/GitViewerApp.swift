import SwiftUI

@MainActor
@main
struct GitViewerApp: App {
    @State private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appViewModel)
                .focusedValue(\.appViewModel, appViewModel)
        }
        .commands {
            AppCommands()
        }
        .defaultSize(width: 1280, height: 800)
    }
}
