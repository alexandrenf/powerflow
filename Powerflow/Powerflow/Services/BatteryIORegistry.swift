import Foundation
import IOKit

struct PowerTelemetryData {
    var adapterEfficiencyLoss: Int32 = 0
    var batteryPower: Int64 = 0
    var systemCurrentIn: Int32 = 0
    var systemLoad: Int64 = 0
    var systemPowerIn: Int32 = 0
}

enum BatteryIORegistryReader {
    static func read() -> BatteryIORegistry? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        guard let dict = copyProperties(from: service) else { return nil }

        let adapter = dictionaryValue(dict["AdapterDetails"])
        let telemetry = dictionaryValue(dict["PowerTelemetryData"])
        let charger = dictionaryValue(dict["ChargerData"])
        let batteryData = dictionaryValue(dict["BatteryData"])
        let isCharging = boolValue(dict["IsCharging"])
            || boolValue(charger?["IsCharging"])
            || intValue(charger?["IsCharging"]) != 0

        let rawMax = intValue(dict["AppleRawMaxCapacity"])
        let rawCurrent = intValue(dict["AppleRawCurrentCapacity"])
        let fullCharge = intValue(batteryData?["FullChargeCapacity"])
        let nominalCharge = intValue(batteryData?["NominalChargeCapacity"])
        let remaining = intValue(batteryData?["RemainingCapacity"])
        let design = intValue(dict["DesignCapacity"])
        let batteryDesign = intValue(batteryData?["DesignCapacity"])

        return BatteryIORegistry(
            adapterName: stringValue(adapter?["Name"]) ?? stringValue(adapter?["Description"]),
            adapterWatts: intValue(adapter?["Watts"]),
            adapterVoltage: intValue(adapter?["AdapterVoltage"]),
            adapterCurrent: intValue(adapter?["Current"]),
            adapterEfficiencyLoss: intValue(telemetry?["AdapterEfficiencyLoss"]),
            currentCapacity: intValue(dict["CurrentCapacity"]),
            appleRawCurrentCapacity: rawCurrent,
            appleRawMaxCapacity: rawMax,
            fullChargeCapacity: fullCharge,
            nominalChargeCapacity: nominalCharge,
            remainingCapacity: remaining,
            cycleCount: intValue(dict["CycleCount"]),
            designCapacity: design > 0 ? design : batteryDesign,
            temperatureCentiCelsius: intValue(dict["Temperature"]),
            updateTime: int64Value(dict["UpdateTime"]),
            isCharging: isCharging,
            timeRemainingMinutes: intValue(dict["TimeRemaining"]),
            telemetry: parseTelemetry(telemetry)
        )
    }

    static func computerName() -> String? {
        Host.current().localizedName
    }

    private static func copyProperties(from service: io_service_t) -> [String: Any]? {
        var properties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0)
        guard result == KERN_SUCCESS, let cfDict = properties?.takeRetainedValue() else {
            return nil
        }
        return cfDict as? [String: Any]
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

    private static func dictionaryValue(_ value: Any?) -> [String: Any]? {
        if let dict = value as? [String: Any] { return dict }
        if let dict = value as? NSDictionary { return dict as? [String: Any] }
        return nil
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
