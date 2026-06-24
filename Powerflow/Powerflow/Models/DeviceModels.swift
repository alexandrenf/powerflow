import Foundation

enum PowerSource: Hashable {
    case local
    case remote(udid: String)
}

enum DeviceAction: Int32 {
    case attached = 1
    case detached = 2
    case notificationStopped = 3
    case paired = 4
}

enum DeviceInterface: Int32, Hashable, CaseIterable {
    case unknown = 0
    case usb = 1
    case wifi = 2

    var displayName: String {
        switch self {
        case .unknown: "Unknown"
        case .usb: "USB"
        case .wifi: "WiFi"
        }
    }

    init(mobileDeviceType: MDInterfaceType) {
        self = DeviceInterface(rawValue: mobileDeviceType.rawValue) ?? .unknown
    }
}

struct RemoteDevice: Identifiable, Equatable {
    var id: String { udid }
    let udid: String
    var name: String
    var interfaces: Set<DeviceInterface> = []
    var current: NormalizedResource = .init()
    var statistics: [StatisticPoint] = []
    var isLoading = true

    var isOffline: Bool { interfaces.isEmpty }
}
