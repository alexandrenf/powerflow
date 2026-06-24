import Foundation
import Observation

@MainActor
@Observable
final class DeviceMonitor {
    private(set) var devices: [String: RemoteDevice] = [:]

    var onPowerUpdate: ((String, NormalizedResource) -> Void)?

    private var connections: [String: DeviceConnection] = [:]
    private var pollTimer: Timer?
    private var notificationThread: Thread?
    private var notificationContext: NotificationContext?

    var sortedDevices: [RemoteDevice] {
        devices.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func remoteDevice(_ udid: String) -> RemoteDevice? {
        devices[udid]
    }

    func start(pollInterval: TimeInterval = 2.0) {
        startNotificationLoop()
        schedulePoll(interval: pollInterval)
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        connections.values.forEach { $0.invalidate() }
        connections.removeAll()
    }

    func refreshInterval(_ interval: TimeInterval) {
        schedulePoll(interval: interval)
    }

    private func startNotificationLoop() {
        let context = NotificationContext(owner: self)
        notificationContext = context
        let retained = Unmanaged.passRetained(context)

        notificationThread = Thread {
            var subscription: UnsafeMutableRawPointer?
            _ = MDSubscribeDeviceNotifications({ info, context in
                guard let info, let context else { return }
                let box = Unmanaged<NotificationContext>.fromOpaque(context).takeUnretainedValue()
                guard let udidCString = MDCopyDeviceUDID(info.pointee.deviceRef) else { return }
                let udid = String(cString: udidCString)
                free(udidCString)

                let action = DeviceAction(rawValue: info.pointee.action.rawValue) ?? .detached
                let interface: DeviceInterface
                if let deviceRef = info.pointee.deviceRef {
                    interface = DeviceInterface(mobileDeviceType: MDGetInterfaceType(deviceRef))
                } else {
                    interface = .unknown
                }

                Task { @MainActor in
                    box.owner?.handleNotification(
                        udid: udid,
                        action: action,
                        interface: interface,
                        deviceRef: info.pointee.deviceRef
                    )
                }
            }, retained.toOpaque(), &subscription)
            MDRunCurrentRunLoop()
        }
        notificationThread?.name = "com.powerflow.mobiledevice"
        notificationThread?.start()
    }

    fileprivate func handleNotification(
        udid: String,
        action: DeviceAction,
        interface: DeviceInterface,
        deviceRef: UnsafeMutableRawPointer?
    ) {
        switch action {
        case .attached:
            guard MDPrepareDevice(deviceRef) == 0,
                  let connection = DeviceConnection(deviceRef: deviceRef) else {
                return
            }
            var device = devices[udid] ?? RemoteDevice(udid: udid, name: udid, isLoading: true)
            device.interfaces.insert(interface)
            if let name = connection.deviceName, !name.isEmpty {
                device.name = name
            }
            devices[udid] = device
            connections[udid] = connection
            pollDevice(udid: udid)

        case .detached:
            guard var device = devices[udid] else { return }
            device.interfaces.remove(interface)
            devices[udid] = device
            if device.interfaces.isEmpty {
                connections[udid]?.invalidate()
                connections.removeValue(forKey: udid)
            }

        case .paired, .notificationStopped:
            break
        }
    }

    private func schedulePoll(interval: TimeInterval) {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollAll() }
        }
        if let pollTimer {
            RunLoop.main.add(pollTimer, forMode: .common)
        }
    }

    private func pollAll() {
        for udid in connections.keys {
            pollDevice(udid: udid)
        }
    }

    private func pollDevice(udid: String) {
        guard let connection = connections[udid],
              var device = devices[udid],
              !device.isOffline else {
            return
        }

        guard let io = connection.fetchIORegistry() else { return }
        let resource = RemotePowerDecoder.normalize(io)
        device.current = resource
        device.isLoading = false
        appendStatistic(to: &device, resource: resource)
        devices[udid] = device
        onPowerUpdate?(udid, resource)
    }

    private func appendStatistic(to device: inout RemoteDevice, resource: NormalizedResource) {
        let point = StatisticPoint(
            timestamp: Date(),
            systemLoad: resource.systemLoad,
            systemIn: resource.systemIn,
            batteryPower: resource.batteryPower,
            batteryLevel: Float(resource.batteryLevel),
            brightnessPower: 0,
            heatpipePower: 0
        )
        device.statistics.append(point)
        if device.statistics.count > 20 {
            device.statistics.removeFirst(device.statistics.count - 20)
        }
    }
}

private final class NotificationContext {
    weak var owner: DeviceMonitor?

    init(owner: DeviceMonitor) {
        self.owner = owner
    }
}
