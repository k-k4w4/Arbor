import SwiftUI

private struct AppViewModelKey: FocusedValueKey {
    typealias Value = AppViewModel
}

extension FocusedValues {
    var appViewModel: AppViewModel? {
        get { self[AppViewModelKey.self] }
        set { self[AppViewModelKey.self] = newValue }
    }
}

struct AppCommands: Commands {
    @FocusedValue(\.appViewModel) private var appViewModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {}
        CommandGroup(after: .sidebar) {
            Button("リフレッシュ") {
                appViewModel?.refresh()
            }
            .keyboardShortcut("r", modifiers: .command)
        }
    }
}
