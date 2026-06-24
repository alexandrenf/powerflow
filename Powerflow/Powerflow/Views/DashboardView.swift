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
            if appModel.power.statistics.isEmpty {
                ContentUnavailableView("Waiting for data", systemImage: "chart.line.uptrend.xyaxis")
                    .frame(height: 180)
            } else {
                ChartContent(points: appModel.power.statistics)
                    .frame(height: 180)
            }
        }
    }
}

private struct ChartContent: View {
    let points: [StatisticPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                legendDot(color: .purple, label: "System")
                legendDot(color: .yellow, label: "Input")
                legendDot(color: .green, label: "Battery")
            }
            .font(.caption2)

            GeometryReader { proxy in
                let maxValue = max(
                    points.map { max($0.systemLoad, max($0.systemIn, abs($0.batteryPower))) }.max() ?? 1,
                    1
                )
                ZStack {
                    linePath(for: \.systemLoad, color: .purple, max: maxValue, in: proxy.size)
                    linePath(for: \.systemIn, color: .yellow, max: maxValue, in: proxy.size)
                    linePath(for: \.batteryPower, color: .green, max: maxValue, in: proxy.size)
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
        let resource = appModel.power.current
        let loading = appModel.power.isLoading

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
