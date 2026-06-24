import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var preferences = appModel.preferences

        Form {
            Section(L10n("appearance")) {
                Picker(L10n("theme"), selection: $preferences.theme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.rawValue.capitalized).tag(theme)
                    }
                }
                .onChange(of: preferences.theme) { _, _ in
                    appModel.applyTheme()
                }

                Picker(L10n("language"), selection: $preferences.language) {
                    Text("English").tag("en")
                    Text("中文").tag("zh-CN")
                }
                .onChange(of: preferences.language) { _, newValue in
                    Localization.shared.setLanguage(newValue)
                }

                Toggle(L10n("animations"), isOn: $preferences.animationsEnabled)
            }

            Section(L10n("updates_monitoring")) {
                Stepper(value: $preferences.updateIntervalMs, in: 500...10_000, step: 500) {
                    Text(L10n("update_interval", preferences.updateIntervalMs))
                }
                .onChange(of: preferences.updateIntervalMs) { _, newValue in
                    let interval = Double(newValue) / 1000
                    appModel.power.refreshInterval(interval)
                    appModel.devices.refreshInterval(interval)
                }

                Toggle(L10n("background_monitoring"), isOn: .constant(true))
                    .disabled(true)

                Picker(L10n("status_bar_item"), selection: $preferences.statusBarItem) {
                    ForEach(StatusBarItem.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }

                Toggle(L10n("show_charging_power"), isOn: $preferences.statusBarShowCharging)
            }

            Section(L10n("about")) {
                LabeledContent(L10n("version"), value: "0.3.0")
                LabeledContent(L10n("license"), value: "MIT License")
                LabeledContent(L10n("author"), value: "Samuel Lyon")
                HStack {
                    Text(L10n("repository"))
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
