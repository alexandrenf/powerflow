import AppKit
import SwiftUI

/// Intercepts the main window close button so the app hides to the menu bar instead of quitting.
struct MainWindowLifecycle: NSViewRepresentable {
    let onClose: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                context.coordinator.attach(to: window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                context.coordinator.attach(to: window)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onClose: onClose)
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        private let onClose: () -> Void
        private weak var window: NSWindow?

        init(onClose: @escaping () -> Void) {
            self.onClose = onClose
        }

        func attach(to window: NSWindow) {
            guard self.window !== window else { return }
            self.window?.delegate = nil
            self.window = window
            window.delegate = self
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            onClose()
            return false
        }
    }
}
