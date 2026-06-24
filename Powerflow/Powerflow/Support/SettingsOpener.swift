import SwiftUI

/// Bridges AppModel settings requests to SwiftUI's `openSettings` environment action.
struct SettingsOpener: ViewModifier {
    @Environment(\.openSettings) private var openSettings

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
                openSettings()
            }
    }
}

extension View {
    func handlesSettingsRequests() -> some View {
        modifier(SettingsOpener())
    }
}
