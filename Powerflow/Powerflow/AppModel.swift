import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class AppModel {
    let preferences = PreferencesStore()
    let power = PowerMonitor()
    let devices = DeviceMonitor()
    let history = HistoryStore()

    var showMainWindow = true
    var selectedPowerSource: PowerSource = .local

    private var statusBarController: StatusBarController?
    private var historyRecorder: ChargingHistoryRecorder?
    private var remoteHistoryRecorder: ChargingHistoryRecorder?

    private(set) var isBootstrapped = false

    var activeResource: NormalizedResource {
        switch selectedPowerSource {
        case .local:
            power.current
        case .remote(let udid):
            devices.remoteDevice(udid)?.current ?? .init()
        }
    }

    var activeStatistics: [StatisticPoint] {
        switch selectedPowerSource {
        case .local:
            power.statistics
        case .remote(let udid):
            devices.remoteDevice(udid)?.statistics ?? []
        }
    }

    var activeIsLoading: Bool {
        switch selectedPowerSource {
        case .local:
            power.isLoading
        case .remote(let udid):
            devices.remoteDevice(udid)?.isLoading ?? true
        }
    }

    var activeDeviceName: String {
        switch selectedPowerSource {
        case .local:
            power.macName
        case .remote(let udid):
            devices.remoteDevice(udid)?.name ?? udid
        }
    }

    var activeIsLocal: Bool {
        if case .local = selectedPowerSource { return true }
        return false
    }

    var activeSubtitle: String {
        switch selectedPowerSource {
        case .local:
            "Local"
        case .remote(let udid):
            guard let device = devices.remoteDevice(udid) else { return "offline" }
            if device.isOffline { return "offline" }
            return device.interfaces.map(\.displayName).sorted().joined(separator: " and ")
        }
    }

    func bootstrap() {
        guard !isBootstrapped else { return }
        isBootstrapped = true
        historyRecorder = ChargingHistoryRecorder(historyStore: history)
        remoteHistoryRecorder = ChargingHistoryRecorder(historyStore: history)
        power.onUpdate = { [weak historyRecorder] resource in
            historyRecorder?.process(resource, udid: "local", deviceName: Host.current().localizedName ?? "Mac", isRemote: false)
        }
        devices.onPowerUpdate = { [weak self, weak remoteHistoryRecorder] udid, resource in
            let name = self?.devices.remoteDevice(udid)?.name ?? udid
            remoteHistoryRecorder?.process(resource, udid: udid, deviceName: name, isRemote: true)
        }
        power.start(preferences: preferences)
        devices.start(pollInterval: preferences.updateInterval)
        statusBarController = StatusBarController(appModel: self)
    }

    func openMainWindow() {
        showMainWindow = true
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func hideMainWindow() {
        showMainWindow = false
        for window in NSApp.windows where window.canBecomeMain && !(window is NSPanel) {
            window.orderOut(nil)
        }
        NSApp.setActivationPolicy(.accessory)
    }

    func openSettings() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }

    func applyTheme() {
        switch preferences.theme {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system:
            NSApp.appearance = nil
        }
    }
}
