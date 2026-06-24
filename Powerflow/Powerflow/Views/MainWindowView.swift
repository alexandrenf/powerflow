import SwiftUI

struct MainWindowView: View {
    @Environment(AppModel.self) private var appModel
    @State private var selectedTab: MainTab = .dashboard

    enum MainTab: Hashable {
        case dashboard
        case history
    }

    var body: some View {
        VStack(spacing: 0) {
            TitleBarView(selectedTab: $selectedTab)
            Group {
                switch selectedTab {
                case .dashboard:
                    DashboardView()
                case .history:
                    HistoryView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .background {
            MainWindowLifecycle {
                appModel.hideMainWindow()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openMainWindow)) { _ in
            appModel.openMainWindow()
        }
        .onChange(of: appModel.devices.sortedDevices.map(\.udid)) { _, udids in
            if case .remote(let udid) = appModel.selectedPowerSource, !udids.contains(udid) {
                appModel.selectedPowerSource = .local
            }
        }
    }
}

struct TitleBarView: View {
    @Environment(AppModel.self) private var appModel
    @Binding var selectedTab: MainWindowView.MainTab

    var body: some View {
        HStack(spacing: 12) {
            deviceTabStrip
            VStack(alignment: .leading, spacing: 2) {
                Text(appModel.activeDeviceName)
                    .font(.headline)
                Text(appModel.activeSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Section", selection: $selectedTab) {
                Text(L10n("dashboard")).tag(MainWindowView.MainTab.dashboard)
                Text(L10n("history")).tag(MainWindowView.MainTab.history)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)
            Button {
                appModel.openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var deviceTabStrip: some View {
        HStack(spacing: 4) {
            DeviceTabButton(
                icon: "laptopcomputer",
                isSelected: appModel.selectedPowerSource == .local
            ) {
                appModel.selectedPowerSource = .local
            }

            ForEach(appModel.devices.sortedDevices) { device in
                DeviceTabButton(
                    icon: "iphone",
                    isSelected: appModel.selectedPowerSource == .remote(udid: device.udid)
                ) {
                    appModel.selectedPowerSource = .remote(udid: device.udid)
                }
            }
        }
    }
}

private struct DeviceTabButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body)
                .padding(6)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(isSelected ? "Selected device" : "Switch device")
    }
}
