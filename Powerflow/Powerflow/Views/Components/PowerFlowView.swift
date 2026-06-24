import SwiftUI

struct PowerFlowView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        GroupBox(L10n("power_flow")) {
            let resource = appModel.activeResource
            HStack(spacing: 12) {
                if resource.isCharging {
                    flowNode(title: L10n("adapter"), value: resource.systemIn + resource.data.efficiencyLoss, color: .yellow, symbol: "powerplug.fill")
                    flowArrow
                }

                VStack(spacing: 8) {
                    if appModel.activeIsLocal {
                        HStack(spacing: 8) {
                            flowNode(title: L10n("screen"), value: resource.data.brightnessPower, color: .blue, symbol: "sun.max.fill")
                            flowNode(title: L10n("heatpipe"), value: resource.data.heatpipePower, color: .orange, symbol: "flame.fill")
                        }
                    }
                    flowNode(title: L10n("system"), value: resource.systemLoad, color: .purple, symbol: "laptopcomputer")
                }

                flowArrow

                flowNode(
                    title: resource.isCharging ? L10n("battery_in") : L10n("battery_out"),
                    value: abs(resource.batteryPower),
                    color: .green,
                    symbol: "battery.100"
                )
            }
            .frame(maxWidth: .infinity, minHeight: 120)
        }
    }

    private var flowArrow: some View {
        Image(systemName: "arrow.right")
            .foregroundStyle(.secondary)
    }

    private func flowNode(title: String, value: Float, color: Color, symbol: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
            Text(String(format: "%.1f W", value))
                .font(.caption.monospacedDigit())
        }
        .frame(minWidth: 72)
        .padding(8)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}
