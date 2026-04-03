import AppKit
import Observation

@MainActor
@Observable
final class AppSettings {
    // 0 = system, 1 = light, 2 = dark
    var appearanceMode: Int {
        didSet {
            UserDefaults.standard.set(appearanceMode, forKey: "appearanceMode")
            applyAppearance()
        }
    }
    var showAbsoluteDates: Bool {
        didSet { UserDefaults.standard.set(showAbsoluteDates, forKey: "showAbsoluteDates") }
    }

    init() {
        appearanceMode = UserDefaults.standard.integer(forKey: "appearanceMode")
        showAbsoluteDates = UserDefaults.standard.bool(forKey: "showAbsoluteDates")
        // Apply persisted appearance before the first frame renders.
        switch appearanceMode {
        case 1: NSApp.appearance = NSAppearance(named: .aqua)
        case 2: NSApp.appearance = NSAppearance(named: .darkAqua)
        default: break
        }
    }

    func applyAppearance() {
        switch appearanceMode {
        case 1: NSApp.appearance = NSAppearance(named: .aqua)
        case 2: NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
    }
}
