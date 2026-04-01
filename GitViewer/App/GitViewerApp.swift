import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            sender.windows.first(where: { $0.canBecomeKey && !$0.isSheet })?.makeKeyAndOrderFront(nil)
        }
        return true
    }
}

@MainActor
@main
struct GitViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
