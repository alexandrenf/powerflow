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
                .handlesSettingsRequests()
                .localizedEnvironment()
        }
        .defaultSize(width: 1000, height: 600)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(L10n("about_powerflow")) {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
            }
            CommandGroup(replacing: .appSettings) {
                Button(L10n("settings")) {
                    appModel.openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .appTermination) {
                Button(L10n("quit_powerflow")) {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            CommandGroup(after: .appInfo) {
                Button(L10n("hide_powerflow")) {
                    NSApp.hide(nil)
                }
                .keyboardShortcut("h", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(appModel)
                .frame(minWidth: 700, minHeight: 800)
                .handlesSettingsRequests()
                .localizedEnvironment()
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

