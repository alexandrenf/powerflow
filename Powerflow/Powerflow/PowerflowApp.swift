import AppKit
import SwiftUI
struct PowerflowApp: App {
    @State private var appModel = AppModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        let _ = {
            appDelegate.appModel = appModel
            appModel.bootstrap()
            appModel.applyTheme()
        }()

        WindowGroup("Powerflow") {
            MainWindowView()
                .environment(appModel)
        }
        .defaultSize(width: 1000, height: 600)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    appModel.openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(appModel)
                .frame(minWidth: 700, minHeight: 800)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var appModel: AppModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        appModel?.bootstrap()
        appModel?.applyTheme()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NotificationCenter.default.post(name: .openMainWindow, object: nil)
        }
        return true
    }
}

extension Notification.Name {
    static let openMainWindow = Notification.Name("openMainWindow")
}
