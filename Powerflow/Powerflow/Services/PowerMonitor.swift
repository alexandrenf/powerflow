import Foundation
import Observation

@MainActor
@Observable
final class PowerMonitor {
    private(set) var current: NormalizedResource = .init()
    private(set) var statistics: [StatisticPoint] = []
    private(set) var isLoading = true
    private(set) var macName: String = "Mac"

    private var smc: AppleSMC?
    private var timer: Timer?
    private weak var preferences: PreferencesStore?
    var onUpdate: ((NormalizedResource) -> Void)?

    func start(preferences: PreferencesStore) {
        self.preferences = preferences
        macName = BatteryIORegistryReader.computerName() ?? "Mac"

        do {
            smc = try AppleSMC()
        } catch {
            print("AppleSMC unavailable: \(error)")
        }

        scheduleTimer(interval: preferences.updateInterval)
    }

    func refreshInterval(_ interval: TimeInterval) {
        scheduleTimer(interval: interval)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func scheduleTimer(interval: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
        poll()
    }

    private func poll() {
        guard let io = BatteryIORegistryReader.read() else {
            print("PowerMonitor: failed to read AppleSmartBattery IORegistry")
            isLoading = false
            return
        }

        let smcData = smc?.readPowerData() ?? SMCPowerData()
        current = NormalizedResource.merge(io: io, smc: smcData)
        isLoading = false
        onUpdate?(current)

        #if DEBUG
        if statistics.isEmpty {
            print("PowerMonitor: systemIn=\(current.systemIn)W systemLoad=\(current.systemLoad)W battery=\(current.batteryPower)W level=\(current.batteryLevel)% charging=\(current.isCharging)")
        }
        #endif

        let point = StatisticPoint(
            timestamp: Date(),
            systemLoad: current.systemLoad,
            systemIn: current.systemIn,
            batteryPower: current.batteryPower,
            batteryLevel: Float(current.batteryLevel),
            brightnessPower: current.data.brightnessPower,
            heatpipePower: current.data.heatpipePower
        )
        statistics.append(point)
        if statistics.count > 20 {
            statistics.removeFirst(statistics.count - 20)
        }
    }

    var statusBarTitle: String {
        preferences?.statusBarText(for: current) ?? "0.0 w"
    }
}
