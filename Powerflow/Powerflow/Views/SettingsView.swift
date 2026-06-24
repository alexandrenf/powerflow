import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var preferences = appModel.preferences

        Form {
            Section("Appearance") {
                Picker("Theme", selection: $preferences.theme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.rawValue.capitalized).tag(theme)
                    }
                }
                .onChange(of: preferences.theme) { _, _ in
                    appModel.applyTheme()
                }

                Picker("Language", selection: $preferences.language) {
                    Text("English").tag("en")
                    Text("中文").tag("zh-CN")
                }

                Toggle("Animations", isOn: $preferences.animationsEnabled)
            }

            Section("Updates & Monitoring") {
                Stepper(value: $preferences.updateIntervalMs, in: 500...10_000, step: 500) {
                    Text("Update interval: \(preferences.updateIntervalMs) ms")
                }
                .onChange(of: preferences.updateIntervalMs) { _, newValue in
                    let interval = Double(newValue) / 1000
                    appModel.power.refreshInterval(interval)
                    appModel.devices.refreshInterval(interval)
                }

                Toggle("Background monitoring", isOn: .constant(true))
                    .disabled(true)

                Picker("Status bar item", selection: $preferences.statusBarItem) {
                    ForEach(StatusBarItem.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }

                Toggle("Show charging power", isOn: $preferences.statusBarShowCharging)
            }

            Section("About") {
                LabeledContent("Version", value: "0.3.0")
                LabeledContent("License", value: "MIT License")
                LabeledContent("Author", value: "Samuel Lyon")
                HStack {
                    Text("Repository")
                    Spacer()
                    Link("github.com/lzt1008/powerflow", destination: URL(string: "https://github.com/lzt1008/powerflow")!)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
