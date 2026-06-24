import Foundation

final class DeviceConnection {
    private var connection: UnsafeMutablePointer<MDServiceConnection>?
    private let deviceRef: UnsafeMutableRawPointer?

    var deviceName: String? {
        guard let deviceRef else { return nil }
        guard let cString = MDCopyDeviceName(deviceRef) else { return nil }
        defer { free(cString) }
        return String(cString: cString)
    }

    init?(deviceRef: UnsafeMutableRawPointer?) {
        self.deviceRef = deviceRef
        var conn: UnsafeMutablePointer<MDServiceConnection>?
        guard MDStartDiagnosticsRelay(deviceRef, &conn) == 0, let conn else { return nil }
        self.connection = conn
    }

    func fetchIORegistry() -> BatteryIORegistry? {
        guard let connection else { return nil }
        var xml: UnsafeMutablePointer<CChar>?
        guard MDRequestIORegistry(connection, &xml) == 0, let xml else { return nil }
        defer { free(xml) }
        return RemoteIORegistryParser.parse(plistXML: String(cString: xml))
    }

    func invalidate() {
        if let connection {
            MDInvalidateServiceConnection(connection)
        }
        connection = nil
        if let deviceRef {
            MDReleaseDevice(deviceRef)
        }
    }
}
