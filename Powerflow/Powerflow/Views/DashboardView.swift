import SwiftUI

struct DashboardView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 24) {
                    PowerStatusView()
                        .frame(minWidth: 320, maxWidth: .infinity)
                    PowerFlowView()
                        .frame(maxWidth: .infinity)
                }
                PowerUsageChartView()
                TechnicalDetailView()
            }
            .padding(20)
        }
    }
}

struct PowerUsageChartView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        GroupBox("Power Usage") {
            if appModel.activeStatistics.isEmpty {
                ContentUnavailableView("Waiting for data", systemImage: "chart.line.uptrend.xyaxis")
                    .frame(height: 180)
            } else {
                ChartContent(
                    points: appModel.activeStatistics,
                    isCharging: appModel.activeResource.isCharging,
                    isLocal: appModel.activeIsLocal
                )
                .frame(height: 180)
            }
        }
    }
}

private struct ChartContent: View {
    let points: [StatisticPoint]
    let isCharging: Bool
    let isLocal: Bool

    private struct Series: Identifiable {
        let id: String
        let label: String
        let color: Color
        let keyPath: KeyPath<StatisticPoint, Float>
    }

    private var series: [Series] {
        if isCharging {
            return [
                Series(id: "systemIn", label: "System In", color: .yellow, keyPath: \.systemIn),
                Series(id: "system", label: "System", color: .purple, keyPath: \.systemLoad),
                Series(id: "battery", label: "Battery", color: .green, keyPath: \.batteryPower),
            ]
        }
        if isLocal {
            return [
                Series(id: "system", label: "System", color: .purple, keyPath: \.systemLoad),
                Series(id: "screen", label: "Screen", color: .blue, keyPath: \.brightnessPower),
                Series(id: "heatpipe", label: "Heatpipe", color: .orange, keyPath: \.heatpipePower),
            ]
        }
        return [
            Series(id: "system", label: "System", color: .purple, keyPath: \.systemLoad),
            Series(id: "battery", label: "Battery", color: .green, keyPath: \.batteryPower),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ForEach(series) { item in
                    legendDot(color: item.color, label: item.label)
                }
            }
            .font(.caption2)

            GeometryReader { proxy in
                let maxValue = max(
                    points.flatMap { point in
                        series.map { abs(point[keyPath: $0.keyPath]) }
                    }.max() ?? 1,
                    1
                )
                ZStack {
                    ForEach(series) { item in
                        linePath(for: item.keyPath, color: item.color, max: maxValue, in: proxy.size)
                    }
                }
            }
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).foregroundStyle(.secondary)
        }
    }

    private func linePath(
        for keyPath: KeyPath<StatisticPoint, Float>,
        color: Color,
        max maxValue: Float,
        in size: CGSize
    ) -> some View {
        Path { path in
            for (index, point) in points.enumerated() {
                let x = size.width * CGFloat(index) / CGFloat(max(points.count - 1, 1))
                let value = abs(point[keyPath: keyPath])
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

struct TechnicalDetailView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        let resource = appModel.activeResource
        let loading = appModel.activeIsLoading

        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
            metricCard(
                title: "Temperature",
                value: loading ? "…" : temperatureText(resource.temperature),
                subtitle: "Battery temperature"
            )
            metricCard(
                title: "Battery Health",
                value: loading ? "…" : healthText(max: resource.maxCapacity, design: resource.designCapacity),
                subtitle: "Max vs design capacity"
            )
            metricCard(
                title: "Cycle Count",
                value: loading ? "…" : "\(resource.cycleCount) times",
                subtitle: "Charge cycles"
            )
            metricCard(
                title: "Energy",
                value: loading ? "…" : "\(resource.currentCapacity) mAh",
                subtitle: loading ? "" : "Max capacity: \(resource.maxCapacity) mAh"
            )
        }
    }

    private func metricCard(title: String, value: String, subtitle: String) -> some View {
        GroupBox(title) {
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title3.monospacedDigit())
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func temperatureText(_ value: Float) -> String {
        guard value > 0 else { return "—" }
        return String(format: "%.1f°C", value)
    }

    private func healthText(max: Int32, design: Int32) -> String {
        guard design > 0, max > 0 else { return "—" }
        return String(format: "%.1f%%", Float(max) / Float(design) * 100)
    }
}
