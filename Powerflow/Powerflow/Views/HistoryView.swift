import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct HistoryView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Group {
            if appModel.history.isLoading {
                ProgressView("Loading history…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appModel.history.sessions.isEmpty {
                ContentUnavailableView(
                    "No history recorded yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Charging sessions will appear here after you charge your Mac.")
                )
            } else {
                @Bindable var history = appModel.history
                NavigationSplitView {
                    List(history.sessions, selection: $history.selectedSession) { session in
                        HistoryListItemView(session: session)
                    }
                    .navigationTitle("History")
                } detail: {
                    if let session = history.selectedSession {
                        HistoryDetailView(session: session)
                    } else {
                        ContentUnavailableView("Select a session", systemImage: "sidebar.left")
                    }
                }
            }
        }
        .task {
            await appModel.history.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .historyRecorded)) { _ in
            Task { await appModel.history.refresh() }
        }
    }
}

struct HistoryListItemView: View {
    let session: ChargingHistory

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: session.isRemote ? "iphone" : "laptopcomputer")
                Text(session.name.isEmpty ? "Device" : session.name)
                    .font(.headline)
            }
            Text("\(session.fromLevel)% → \(session.endLevel)%")
                .font(.subheadline)
            Text(durationText(seconds: session.chargingTime))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func durationText(seconds: Int64) -> String {
        let minutes = Int(seconds) / 60
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }
}

struct HistoryDetailView: View {
    @Environment(AppModel.self) private var appModel
    let session: ChargingHistory

    @State private var detail: ChargingHistoryDetail?
    @State private var isLoadingDetail = true

    var body: some View {
        Group {
            if isLoadingDetail {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let detail {
                detailContent(detail)
            } else {
                ContentUnavailableView("Detail unavailable", systemImage: "exclamationmark.triangle")
            }
        }
        .padding(24)
        .task(id: session.id) {
            isLoadingDetail = true
            detail = await appModel.history.loadDetail(for: session.id)
            isLoadingDetail = false
        }
    }

    @ViewBuilder
    private func detailContent(_ detail: ChargingHistoryDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.name.isEmpty ? "Device" : session.name)
                            .font(.title2.bold())
                        Text("with \(session.adapterName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Menu {
                        Button("Export JSON…") {
                            exportDetail(detail)
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            Task { await appModel.history.deleteSession(id: session.id) }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                    .menuStyle(.borderlessButton)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                    summaryCard(title: "Duration", value: formatDuration(session.chargingTime), subtitle: formatTimestamp(session.timestamp))
                    summaryCard(
                        title: "Avg Power",
                        value: String(format: "%.1f W", detail.avg.adapterPower),
                        subtitle: "Peak: \(String(format: "%.1f", detail.peak.adapterPower)) W"
                    )
                    summaryCard(
                        title: "Charging rate",
                        value: chargingRateText,
                        subtitle: "Avg temp: \(String(format: "%.1f", detail.avg.temperature))°C"
                    )
                }

                GroupBox("Charging Curve") {
                    HistoryCurveChart(curve: detail.curve)
                        .frame(height: 200)
                }

                GroupBox("Additional Detail") {
                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                        GridRow {
                            Text("Temperature peak").foregroundStyle(.secondary)
                            Text(String(format: "%.1f°C", detail.peak.temperature))
                        }
                        GridRow {
                            Text("Adapter power peak").foregroundStyle(.secondary)
                            Text(String(format: "%.1f W", detail.peak.adapterPower))
                        }
                        GridRow {
                            Text("Adapter").foregroundStyle(.secondary)
                            Text("\(Int(detail.peak.adapterWatts)) W (\(String(format: "%.1f", detail.peak.adapterVoltage)) V, \(String(format: "%.1f", detail.peak.adapterAmperage)) A)")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var chargingRateText: String {
        guard session.chargingTime > 0 else { return "—" }
        let rate = Double(session.endLevel - session.fromLevel) / Double(session.chargingTime) * 60
        return String(format: "%.2f%%/min", rate)
    }

    private func summaryCard(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatDuration(_ seconds: Int64) -> String {
        let minutes = Int(seconds) / 60
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    private func formatTimestamp(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func exportDetail(_ detail: ChargingHistoryDetail) {
        guard let data = try? JSONEncoder().encode(detail) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "powerflow-history-\(session.id).json"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? data.write(to: url)
        }
    }
}

private struct HistoryCurveChart: View {
    let curve: [NormalizedResource]

    var body: some View {
        GeometryReader { proxy in
            let maxPower = max(curve.map(\.systemIn).max() ?? 1, 1)
            ZStack(alignment: .bottomLeading) {
                chartPath(for: \.systemIn, color: .yellow, max: maxPower, in: proxy.size)
                chartPath(for: \.systemLoad, color: .purple, max: maxPower, in: proxy.size)
                chartPath(for: \.batteryPower, color: .green, max: maxPower, in: proxy.size)
            }
        }
    }

    private func chartPath(
        for keyPath: KeyPath<NormalizedResource, Float>,
        color: Color,
        max maxValue: Float,
        in size: CGSize
    ) -> some View {
        Path { path in
            for (index, point) in curve.enumerated() {
                let x = size.width * CGFloat(index) / CGFloat(max(curve.count - 1, 1))
                let value = point[keyPath: keyPath]
                let y = size.height * (1 - CGFloat(value / maxValue))
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
        .stroke(color, lineWidth: 1.5)
    }
}
