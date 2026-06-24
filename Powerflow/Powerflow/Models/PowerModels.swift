import Foundation

struct NormalizedData: Codable, Equatable {
    var systemIn: Float = 0
    var systemLoad: Float = 0
    var batteryPower: Float = 0
    var adapterPower: Float = 0
    var efficiencyLoss: Float = 0
    var brightnessPower: Float = 0
    var heatpipePower: Float = 0
    var batteryLevel: Int32 = 0
    var absoluteBatteryLevel: Float = 0
    var temperature: Float = 0
    var adapterWatts: Float = 0
    var adapterVoltage: Float = 0
    var adapterAmperage: Float = 0

    func mergedMax(with other: NormalizedData) -> NormalizedData {
        NormalizedData(
            systemIn: Swift.max(systemIn, other.systemIn),
            systemLoad: Swift.max(systemLoad, other.systemLoad),
            batteryPower: Swift.max(batteryPower, other.batteryPower),
            adapterPower: Swift.max(adapterPower, other.adapterPower),
            efficiencyLoss: Swift.max(efficiencyLoss, other.efficiencyLoss),
            brightnessPower: Swift.max(brightnessPower, other.brightnessPower),
            heatpipePower: Swift.max(heatpipePower, other.heatpipePower),
            batteryLevel: Swift.max(batteryLevel, other.batteryLevel),
            absoluteBatteryLevel: Swift.max(absoluteBatteryLevel, other.absoluteBatteryLevel),
            temperature: Swift.max(temperature, other.temperature),
            adapterWatts: Swift.max(adapterWatts, other.adapterWatts),
            adapterVoltage: Swift.max(adapterVoltage, other.adapterVoltage),
            adapterAmperage: Swift.max(adapterAmperage, other.adapterAmperage)
        )
    }

    static func / (lhs: NormalizedData, rhs: Float) -> NormalizedData {
        guard rhs != 0 else { return lhs }
        return NormalizedData(
            systemIn: lhs.systemIn / rhs,
            systemLoad: lhs.systemLoad / rhs,
            batteryPower: lhs.batteryPower / rhs,
            adapterPower: lhs.adapterPower / rhs,
            efficiencyLoss: lhs.efficiencyLoss / rhs,
            brightnessPower: lhs.brightnessPower / rhs,
            heatpipePower: lhs.heatpipePower / rhs,
            batteryLevel: Int32(Float(lhs.batteryLevel) / rhs),
            absoluteBatteryLevel: lhs.absoluteBatteryLevel / rhs,
            temperature: lhs.temperature / rhs,
            adapterWatts: lhs.adapterWatts / rhs,
            adapterVoltage: lhs.adapterVoltage / rhs,
            adapterAmperage: lhs.adapterAmperage / rhs
        )
    }
}

struct NormalizedResource: Codable, Equatable {
    var isLocal: Bool = true
    var isCharging: Bool = false
    var timeRemainSeconds: TimeInterval = 0
    var lastUpdate: Int64 = 0
    var adapterName: String?
    var cycleCount: Int32 = 0
    var currentCapacity: Int32 = 0
    var maxCapacity: Int32 = 0
    var designCapacity: Int32 = 0
    var data: NormalizedData = .init()

    var systemIn: Float { data.systemIn }
    var systemLoad: Float { data.systemLoad }
    var batteryPower: Float { data.batteryPower }
    var batteryLevel: Int32 { data.batteryLevel }
    var temperature: Float { data.temperature }
}

struct SMCPowerData {
    var batteryRate: Float = 0
    var deliveryRate: Float = 0
    var systemTotal: Float = 0
    var heatpipe: Float = 0
    var brightness: Float = 0
    var fullChargeCapacity: Float = 0
    var currentCapacity: Float = 0
    var chargingStatus: Float = 0
    var timeToEmpty: Float = 0
    var timeToFull: Float = 0
    var temperature: Float = 0

    var isCharging: Bool { chargingStatus > Float.ulpOfOne }
}

struct BatteryIORegistry {
    var adapterName: String?
    var adapterWatts: Int32 = 0
    var adapterVoltage: Int32 = 0
    var adapterCurrent: Int32 = 0
    var adapterEfficiencyLoss: Int32 = 0
    var currentCapacity: Int32 = 0
    var appleRawCurrentCapacity: Int32 = 0
    var appleRawMaxCapacity: Int32 = 0
    var fullChargeCapacity: Int32 = 0
    var nominalChargeCapacity: Int32 = 0
    var remainingCapacity: Int32 = 0
    var cycleCount: Int32 = 0
    var designCapacity: Int32 = 0
    var temperatureCentiCelsius: Int32 = 0
    var updateTime: Int64 = 0
    var isCharging: Bool = false
    var timeRemainingMinutes: Int32 = 0
    var telemetry: PowerTelemetryData?
}

struct StatisticPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let systemLoad: Float
    let systemIn: Float
    let batteryPower: Float
    let batteryLevel: Float
}

enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case system, light, dark
    var id: String { rawValue }
}

enum StatusBarItem: String, CaseIterable, Identifiable, Codable {
    case system, screen, heatpipe
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .screen: "Screen"
        case .heatpipe: "Heatpipe"
        }
    }
}

struct ChargingHistory: Identifiable, Codable, Equatable, Hashable {
    var id: Int64
    var fromLevel: Int64
    var endLevel: Int64
    var chargingTime: Int64
    var timestamp: Int64
    var name: String
    var udid: String
    var isRemote: Bool
    var adapterName: String
}

struct ChargingHistoryDetail: Codable {
    var avg: NormalizedData
    var peak: NormalizedData
    var curve: [NormalizedResource]
    var raw: [String]
}

extension NormalizedResource {
    static func merge(io: BatteryIORegistry, smc: SMCPowerData) -> NormalizedResource {
        let efficiencyLoss = Float(io.adapterEfficiencyLoss) / 1000
        let maxCapacity = io.appleRawMaxCapacity > 1
            ? io.appleRawMaxCapacity
            : Swift.max(io.fullChargeCapacity, io.nominalChargeCapacity, 1)
        let currentMah = io.appleRawCurrentCapacity > 0
            ? io.appleRawCurrentCapacity
            : io.remainingCapacity
        let absoluteLevel = Float(currentMah) / Float(maxCapacity) * 100
        let isCharging = smc.isCharging || io.isCharging

        var systemIn = smc.deliveryRate
        var systemLoad = smc.systemTotal
        var batteryPower = Swift.max(smc.batteryRate, smc.deliveryRate - smc.systemTotal)
        var adapterPower = smc.deliveryRate + efficiencyLoss

        // Fall back to IORegistry PowerTelemetryData when SMC reads are unavailable/zero
        if let ptd = io.telemetry, systemLoad <= 0, systemIn <= 0 {
            systemIn = Float(ptd.systemPowerIn) / 1000
            systemLoad = Float(ptd.systemLoad) / 1000
            batteryPower = Float(ptd.batteryPower) / 1000
            adapterPower = systemIn + efficiencyLoss
        } else if let ptd = io.telemetry {
            if systemIn <= 0 { systemIn = Float(ptd.systemPowerIn) / 1000 }
            if systemLoad <= 0 { systemLoad = Float(ptd.systemLoad) / 1000 }
            if batteryPower <= 0 { batteryPower = Float(ptd.batteryPower) / 1000 }
            if adapterPower <= 0 { adapterPower = systemIn + efficiencyLoss }
        }

        let timeRemainMinutes: Float = {
            if smc.isCharging, smc.timeToFull > 0 { return smc.timeToFull }
            if !smc.isCharging, smc.timeToEmpty > 0 { return smc.timeToEmpty }
            return Float(io.timeRemainingMinutes)
        }()

        var temperature = smc.temperature
        if temperature <= 0, io.temperatureCentiCelsius > 0 {
            temperature = Float(io.temperatureCentiCelsius) / 100
        }

        return NormalizedResource(
            isLocal: true,
            isCharging: isCharging,
            timeRemainSeconds: TimeInterval(60 * timeRemainMinutes),
            lastUpdate: io.updateTime,
            adapterName: io.adapterName,
            cycleCount: io.cycleCount,
            currentCapacity: currentMah,
            maxCapacity: maxCapacity,
            designCapacity: io.designCapacity,
            data: NormalizedData(
                systemIn: systemIn,
                systemLoad: systemLoad,
                batteryPower: batteryPower,
                adapterPower: adapterPower,
                efficiencyLoss: efficiencyLoss,
                brightnessPower: smc.brightness,
                heatpipePower: smc.heatpipe,
                batteryLevel: io.currentCapacity,
                absoluteBatteryLevel: absoluteLevel,
                temperature: temperature,
                adapterWatts: Float(io.adapterWatts),
                adapterVoltage: Float(io.adapterVoltage) / 1000,
                adapterAmperage: Float(io.adapterCurrent) / 1000
            )
        )
    }
}
