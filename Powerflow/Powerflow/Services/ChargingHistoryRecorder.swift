import Foundation

@MainActor
final class ChargingHistoryRecorder {
    private var staged: [ChargingHistoryStage] = []
    private weak var historyStore: HistoryStore?

    init(historyStore: HistoryStore) {
        self.historyStore = historyStore
    }

    func process(_ resource: NormalizedResource) {
        let fullCharged = resource.batteryLevel == 100

        if let last = staged.last, last.data.isCharging && !resource.isCharging {
            finalizeSession()
        } else if !staged.isEmpty && fullCharged {
            finalizeSession()
        }

        let shouldAppend = resource.isCharging
            && !fullCharged
            && (staged.last?.data.lastUpdate != resource.lastUpdate || staged.isEmpty)

        guard shouldAppend else { return }

        let raw = (try? JSONEncoder().encode(resource)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        staged.append(ChargingHistoryStage(data: resource, raw: raw))
    }

    private func finalizeSession() {
        let captured = staged
        staged = []
        guard captured.count > 2, let historyStore else { return }

        Task {
            let inputs = captured.map { ChargingHistoryStageInput(data: $0.data, raw: $0.raw) }
            await historyStore.saveSession(stages: inputs, deviceName: Host.current().localizedName ?? "Mac")
        }
    }
}

private struct ChargingHistoryStage {
    let data: NormalizedResource
    let raw: String
}
