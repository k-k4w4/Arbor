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
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appViewModel)
                .environment(settings)
                .focusedValue(\.appViewModel, appViewModel)
                .onAppear { settings.applyAppearance() }
        }
        .commands {
            AppCommands()
        }
        .defaultSize(width: 1280, height: 800)

        Settings {
            PreferencesView()
                .environment(settings)
        }
    }
}
