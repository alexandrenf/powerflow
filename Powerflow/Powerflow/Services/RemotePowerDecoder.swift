import Foundation

enum RemotePowerDecoder {
    static func normalize(_ io: BatteryIORegistry) -> NormalizedResource {
        var resource = NormalizedResource()
        resource.isLocal = false
        resource.isCharging = io.isCharging
        resource.timeRemainSeconds = TimeInterval(io.timeRemainingMinutes * 60)
        resource.lastUpdate = io.updateTime
        resource.adapterName = io.adapterName
        resource.cycleCount = io.cycleCount
        resource.currentCapacity = io.appleRawCurrentCapacity > 0 ? io.appleRawCurrentCapacity : io.remainingCapacity
        resource.maxCapacity = io.appleRawMaxCapacity > 0 ? io.appleRawMaxCapacity : io.fullChargeCapacity
        resource.designCapacity = io.designCapacity

        if let telemetry = io.telemetry {
            resource.data.systemIn = Float(telemetry.systemPowerIn) / 1000
            resource.data.systemLoad = Float(telemetry.systemLoad) / 1000
            resource.data.batteryPower = Float(telemetry.batteryPower) / 1000
            resource.data.adapterPower = Float(telemetry.systemPowerIn + telemetry.adapterEfficiencyLoss) / 1000
            resource.data.efficiencyLoss = Float(telemetry.adapterEfficiencyLoss) / 1000
        }

        resource.data.batteryLevel = io.currentCapacity
        let maxCap = max(resource.maxCapacity, 1)
        resource.data.absoluteBatteryLevel = Float(resource.currentCapacity) / Float(maxCap) * 100
        resource.data.temperature = Float(io.temperatureCentiCelsius) / 100
        resource.data.adapterWatts = Float(io.adapterWatts)
        resource.data.adapterVoltage = Float(io.adapterVoltage) / 1000
        resource.data.adapterAmperage = Float(io.adapterCurrent) / 1000
        return resource
    }
}

enum RemoteIORegistryParser {
    static func parse(plistXML: String) -> BatteryIORegistry? {
        guard let data = plistXML.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let root = plist as? [String: Any],
              let diagnostics = root["Diagnostics"] as? [String: Any],
              let ioRegistry = diagnostics["IORegistry"] as? [String: Any] else {
            return nil
        }
        return parseIORegistryDictionary(ioRegistry)
    }

    private static func parseIORegistryDictionary(_ dict: [String: Any]) -> BatteryIORegistry? {
        let adapter = dict["AdapterDetails"] as? [String: Any]
        let telemetry = dict["PowerTelemetryData"] as? [String: Any]
        let isCharging = boolValue(dict["IsCharging"])

        return BatteryIORegistry(
            adapterName: stringValue(adapter?["Name"]) ?? stringValue(adapter?["Description"]),
            adapterWatts: intValue(adapter?["Watts"]),
            adapterVoltage: intValue(adapter?["AdapterVoltage"]),
            adapterCurrent: intValue(adapter?["Current"]),
            adapterEfficiencyLoss: intValue(telemetry?["AdapterEfficiencyLoss"]),
            currentCapacity: intValue(dict["CurrentCapacity"]),
            appleRawCurrentCapacity: intValue(dict["AppleRawCurrentCapacity"]),
            appleRawMaxCapacity: intValue(dict["AppleRawMaxCapacity"]),
            fullChargeCapacity: intValue(dict["FullChargeCapacity"]),
            nominalChargeCapacity: intValue(dict["NominalChargeCapacity"]),
            remainingCapacity: intValue(dict["RemainingCapacity"]),
            cycleCount: intValue(dict["CycleCount"]),
            designCapacity: intValue(dict["DesignCapacity"]),
            temperatureCentiCelsius: intValue(dict["Temperature"]),
            updateTime: int64Value(dict["UpdateTime"]),
            isCharging: isCharging,
            timeRemainingMinutes: intValue(dict["TimeRemaining"]),
            telemetry: parseTelemetry(telemetry)
        )
    }

    private static func parseTelemetry(_ dict: [String: Any]?) -> PowerTelemetryData? {
        guard let dict else { return nil }
        return PowerTelemetryData(
            adapterEfficiencyLoss: intValue(dict["AdapterEfficiencyLoss"]),
            batteryPower: int64Value(dict["BatteryPower"]),
            systemCurrentIn: intValue(dict["SystemCurrentIn"]),
            systemLoad: int64Value(dict["SystemLoad"]),
            systemPowerIn: intValue(dict["SystemPowerIn"])
        )
    }

    private static func stringValue(_ value: Any?) -> String? {
        switch value {
        case let string as String: return string
        case let number as NSNumber: return number.stringValue
        default: return nil
        }
    }

    private static func boolValue(_ value: Any?) -> Bool {
        switch value {
        case let bool as Bool: return bool
        case let number as NSNumber: return number.boolValue
        case let string as String:
            switch string.lowercased() {
            case "yes", "true", "1": return true
            default: return false
            }
        default: return false
        }
    }

    private static func intValue(_ value: Any?) -> Int32 {
        switch value {
        case let number as NSNumber: return number.int32Value
        case let int as Int: return Int32(int)
        default: return 0
        }
    }

    private static func int64Value(_ value: Any?) -> Int64 {
        switch value {
        case let number as NSNumber: return number.int64Value
        case let int as Int: return Int64(int)
        default: return 0
        }
    }
}
