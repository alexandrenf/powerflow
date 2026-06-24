import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class AppModel {
    let preferences = PreferencesStore()
    let power = PowerMonitor()
    let history = HistoryStore()

    var showMainWindow = true

    private var statusBarController: StatusBarController?
    private var historyRecorder: ChargingHistoryRecorder?

    private(set) var isBootstrapped = false

    func bootstrap() {
        guard !isBootstrapped else { return }
        isBootstrapped = true
        historyRecorder = ChargingHistoryRecorder(historyStore: history)
        power.onUpdate = { [weak historyRecorder] resource in
            historyRecorder?.process(resource)
        }
        power.start(preferences: preferences)
        statusBarController = StatusBarController(appModel: self)
    }

    func openMainWindow() {
        showMainWindow = true
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func hideMainWindow() {
        showMainWindow = false
        for window in NSApp.windows where window.canBecomeMain && !(window is NSPanel) {
            window.orderOut(nil)
        }
        NSApp.setActivationPolicy(.accessory)
    }

    func openSettings() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }

    func applyTheme() {
        switch preferences.theme {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system:
            NSApp.appearance = nil
        }
    }
}
