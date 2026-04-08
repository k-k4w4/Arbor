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
struct ArborApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var settings: AppSettings
    @State private var appViewModel: AppViewModel

    init() {
        let s = AppSettings()
        _settings = State(initialValue: s)
        _appViewModel = State(initialValue: AppViewModel(settings: s))
    }

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
