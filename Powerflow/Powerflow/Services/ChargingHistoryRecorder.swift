import Foundation

@MainActor
final class ChargingHistoryRecorder {
    private var staged: [String: [ChargingHistoryStage]] = [:]
    private weak var historyStore: HistoryStore?

    init(historyStore: HistoryStore) {
        self.historyStore = historyStore
    }

    func process(
        _ resource: NormalizedResource,
        udid: String,
        deviceName: String,
        isRemote: Bool
    ) {
        let sessionKey = "\(udid)-\(isRemote)"
        let fullCharged = resource.batteryLevel == 100

        if let last = staged[sessionKey]?.last, last.data.isCharging && !resource.isCharging {
            finalizeSession(sessionKey: sessionKey, udid: udid, deviceName: deviceName, isRemote: isRemote)
        } else if let stages = staged[sessionKey], !stages.isEmpty && fullCharged {
            finalizeSession(sessionKey: sessionKey, udid: udid, deviceName: deviceName, isRemote: isRemote)
        }

        let shouldAppend = resource.isCharging
            && !fullCharged
            && (staged[sessionKey]?.last?.data.lastUpdate != resource.lastUpdate || staged[sessionKey] == nil)

        guard shouldAppend else { return }

        let raw = (try? JSONEncoder().encode(resource)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        var stages = staged[sessionKey] ?? []
        stages.append(ChargingHistoryStage(data: resource, raw: raw))
        staged[sessionKey] = stages
    }

    private func finalizeSession(sessionKey: String, udid: String, deviceName: String, isRemote: Bool) {
        let captured = staged[sessionKey] ?? []
        staged[sessionKey] = nil
        guard captured.count > 2, let historyStore else { return }

        Task {
            let inputs = captured.map { ChargingHistoryStageInput(data: $0.data, raw: $0.raw) }
            await historyStore.saveSession(
                stages: inputs,
                deviceName: deviceName,
                udid: udid,
                isRemote: isRemote
            )
        }
    }
}

private struct ChargingHistoryStage {
    let data: NormalizedResource
    let raw: String
}
