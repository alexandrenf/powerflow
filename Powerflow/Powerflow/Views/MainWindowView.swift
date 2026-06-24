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
    }
}

struct TitleBarView: View {
    @Environment(AppModel.self) private var appModel
    @Binding var selectedTab: MainWindowView.MainTab

    var body: some View {
        HStack {
            Text(appModel.power.macName)
                .font(.headline)
            Text("Local")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Picker("Section", selection: $selectedTab) {
                Text("Dashboard").tag(MainWindowView.MainTab.dashboard)
                Text("History").tag(MainWindowView.MainTab.history)
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
}
