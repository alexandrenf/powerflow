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
        GroupBox(L10n("power_usage")) {
            if appModel.activeStatistics.isEmpty {
                ContentUnavailableView(L10n("waiting_for_data"), systemImage: "chart.line.uptrend.xyaxis")
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
                Series(id: "systemIn", label: L10n("chart_system_in"), color: .yellow, keyPath: \.systemIn),
                Series(id: "system", label: L10n("chart_system"), color: .purple, keyPath: \.systemLoad),
                Series(id: "battery", label: L10n("chart_battery"), color: .green, keyPath: \.batteryPower),
            ]
        }
        if isLocal {
            return [
                Series(id: "system", label: L10n("chart_system"), color: .purple, keyPath: \.systemLoad),
                Series(id: "screen", label: L10n("chart_screen"), color: .blue, keyPath: \.brightnessPower),
                Series(id: "heatpipe", label: L10n("chart_heatpipe"), color: .orange, keyPath: \.heatpipePower),
            ]
        }
        return [
            Series(id: "system", label: L10n("chart_system"), color: .purple, keyPath: \.systemLoad),
            Series(id: "battery", label: L10n("chart_battery"), color: .green, keyPath: \.batteryPower),
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
                title: L10n("temperature"),
                value: loading ? "…" : temperatureText(resource.temperature),
                subtitle: L10n("battery_temperature")
            )
            metricCard(
                title: L10n("battery_health"),
                value: loading ? "…" : healthText(max: resource.maxCapacity, design: resource.designCapacity),
                subtitle: L10n("battery_health_desc")
            )
            metricCard(
                title: L10n("cycle_count"),
                value: loading ? "…" : "\(resource.cycleCount) \(L10n("times"))",
                subtitle: L10n("cycle_count_desc")
            )
            metricCard(
                title: L10n("energy"),
                value: loading ? "…" : "\(resource.currentCapacity) mAh",
                subtitle: loading ? "" : "\(L10n("max_capacity")): \(resource.maxCapacity) mAh"
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
