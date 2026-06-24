import SwiftUI

struct PowerStatusView: View {
    @Environment(AppModel.self) private var appModel
    var isPopover = false

    private var resource: NormalizedResource {
        isPopover ? appModel.power.current : appModel.activeResource
    }

    private var loading: Bool {
        isPopover ? appModel.power.isLoading : appModel.activeIsLoading
    }

    var body: some View {
        Group {
            if isPopover {
                content(resource: resource, loading: loading)
            } else {
                GroupBox {
                    content(resource: resource, loading: loading)
                }
            }
        }
    }

    @ViewBuilder
    private func content(resource: NormalizedResource, loading: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(resource.isCharging ? "Charging Power" : "System Power")
                        .font(.headline)
                    Text(subtitle(for: resource))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if resource.isCharging {
                    Text(String(format: "%.0fW adapter", resource.data.adapterWatts))
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.yellow.opacity(0.2), in: Capsule())
                }
            }

            if loading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 48)
            } else {
                Text(displayWatts(for: resource))
                    .font(.system(size: 42, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(appModel.preferences.animationsEnabled ? .default : nil, value: displayWatts(for: resource))
            }

            HStack {
                batteryIcon(level: resource.batteryLevel, charging: resource.isCharging)
                Text(String(format: "%.2f%%", Float(resource.batteryLevel)))
                    .monospacedDigit()
                Spacer()
                if resource.isCharging && resource.batteryLevel == 100 {
                    Text("Fully charged")
                        .foregroundStyle(.secondary)
                } else {
                    Text(remainingText(for: resource))
                        .foregroundStyle(.secondary)
                }
            }

            PowerStatusBarView(resource: resource)
        }
    }

    private func displayWatts(for resource: NormalizedResource) -> String {
        String(format: "%.1f W", resource.isCharging ? resource.systemIn : resource.systemLoad)
    }

    private func subtitle(for resource: NormalizedResource) -> String {
        if resource.isCharging {
            return resource.adapterName ?? "Adapter"
        }
        return "On Battery"
    }

    private func remainingText(for resource: NormalizedResource) -> String {
        let minutes = Int(resource.timeRemainSeconds / 60)
        let suffix = resource.isCharging ? "to full" : "to empty"
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m \(suffix)"
        }
        return "\(minutes)m \(suffix)"
    }

    @ViewBuilder
    private func batteryIcon(level: Int32, charging: Bool) -> some View {
        if charging {
            Image(systemName: "battery.100.bolt")
        } else if level > 66 {
            Image(systemName: "battery.100")
        } else if level > 33 {
            Image(systemName: "battery.50")
        } else if level < 10 {
            Image(systemName: "battery.0")
                .foregroundStyle(.red)
        } else {
            Image(systemName: "battery.25")
        }
    }
}

struct PowerStatusBarView: View {
    let resource: NormalizedResource

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 1) {
                ForEach(segments, id: \.label) { segment in
                    Rectangle()
                        .fill(segment.color)
                        .frame(width: max(proxy.size.width * segment.fraction, 1))
                        .help("\(segment.label): \(String(format: "%.1f W", segment.value))")
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .frame(height: 8)
    }

    private struct Segment {
        let label: String
        let value: Float
        let fraction: CGFloat
        let color: Color
    }

    private var segments: [Segment] {
        var items: [(String, Float, Color)] = []
        if resource.isLocal {
            items.append(("Screen", resource.data.brightnessPower, .blue))
            items.append(("Heatpipe", resource.data.heatpipePower, .orange))
            let other = max(resource.systemLoad - resource.data.brightnessPower - resource.data.heatpipePower, 0)
            items.append(("System", other, .purple))
        } else {
            items.append(("System", resource.systemLoad, .purple))
        }
        if resource.isCharging {
            items.append(("Battery", resource.batteryPower, .green))
            items.append(("Loss", resource.data.efficiencyLoss, .gray))
        }
        let total = items.map(\.1).reduce(0, +)
        guard total > 0 else {
            return [Segment(label: "Idle", value: 0, fraction: 1, color: .gray.opacity(0.3))]
        }
        return items.map { label, value, color in
            Segment(label: label, value: value, fraction: CGFloat(value / total), color: color)
        }
    }
}
