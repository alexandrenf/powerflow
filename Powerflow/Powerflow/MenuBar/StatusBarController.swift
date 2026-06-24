import AppKit
import SwiftUI

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private weak var appModel: AppModel?
    private var observation: NSObjectProtocol?

    init(appModel: AppModel) {
        self.appModel = appModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 352, height: 224)
        popover.contentViewController = NSHostingController(
            rootView: PopoverView().environment(appModel)
        )

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Powerflow")
            button.image?.isTemplate = true
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        updateTitle(appModel.power.statusBarTitle)

        observation = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self, weak appModel] _ in
            guard let appModel else { return }
            Task { @MainActor in
                self?.updateTitle(appModel.power.statusBarTitle)
            }
        }

        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self, weak appModel] _ in
            guard let appModel else { return }
            Task { @MainActor in
                self?.updateTitle(appModel.power.statusBarTitle)
            }
        }
    }

    @objc private func statusItemClicked(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent, let button = statusItem.button else { return }

        if event.type == .rightMouseUp {
            let menu = NSMenu()
            let showItem = NSMenuItem(title: "Show Window", action: #selector(showMainWindow), keyEquivalent: "")
            showItem.target = self
            menu.addItem(showItem)
            menu.addItem(.separator())
            let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
            quitItem.target = self
            menu.addItem(quitItem)
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc private func showMainWindow() {
        appModel?.openMainWindow()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func updateTitle(_ title: String) {
        statusItem.button?.title = " \(title)"
    }
}
