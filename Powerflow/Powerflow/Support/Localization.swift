import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class Localization {
    static let shared = Localization()

    private(set) var language: String = "en"

    func setLanguage(_ code: String) {
        language = code
    }

    func string(_ key: String) -> String {
        strings[language]?[key] ?? strings["en"]?[key] ?? key
    }

    private let strings: [String: [String: String]] = [
        "en": [
            "dashboard": "Dashboard",
            "history": "History",
            "local": "Local",
            "offline": "offline",
            "power_flow": "Power Flow",
            "power_usage": "Power Usage",
            "waiting_for_data": "Waiting for data",
            "system_power": "System Power",
            "charging_power": "Charging Power",
            "on_battery": "On Battery",
            "fully_charged": "Fully charged",
            "to_full": "to full",
            "to_empty": "to empty",
            "adapter": "Adapter",
            "screen": "Screen",
            "heatpipe": "Heatpipe",
            "system": "System",
            "battery_in": "Battery In",
            "battery_out": "Battery Out",
            "power_loss": "Power Loss",
            "temperature": "Temperature",
            "battery_temperature": "Battery temperature",
            "battery_health": "Battery Health",
            "battery_health_desc": "Max vs design capacity",
            "cycle_count": "Cycle Count",
            "cycle_count_desc": "Charge cycles",
            "times": "times",
            "energy": "Energy",
            "max_capacity": "Max capacity",
            "loading_history": "Loading history…",
            "no_history": "No history recorded yet",
            "no_history_desc": "Charging sessions will appear here after you charge your Mac.",
            "select_session": "Select a session",
            "detail_unavailable": "Detail unavailable",
            "duration": "Duration",
            "avg_power": "Avg Power",
            "charging_rate": "Charging rate",
            "charging_curve": "Charging Curve",
            "additional_detail": "Additional Detail",
            "temperature_peak": "Temperature peak",
            "adapter_power_peak": "Adapter power peak",
            "export_json": "Export JSON…",
            "delete": "Delete",
            "with_adapter": "with %@",
            "peak_watts": "Peak: %.1f W",
            "avg_temp": "Avg temp: %.1f°C",
            "appearance": "Appearance",
            "theme": "Theme",
            "language": "Language",
            "animations": "Animations",
            "updates_monitoring": "Updates & Monitoring",
            "update_interval": "Update interval: %d ms",
            "background_monitoring": "Background monitoring",
            "status_bar_item": "Status bar item",
            "show_charging_power": "Show charging power",
            "about": "About",
            "version": "Version",
            "license": "License",
            "author": "Author",
            "repository": "Repository",
            "settings": "Settings…",
            "about_powerflow": "About Powerflow",
            "hide_powerflow": "Hide Powerflow",
            "quit_powerflow": "Quit Powerflow",
            "show_window": "Show Window",
            "quit": "Quit",
            "chart_system": "System",
            "chart_system_in": "System In",
            "chart_battery": "Battery",
            "chart_screen": "Screen",
            "chart_heatpipe": "Heatpipe",
            "chart_input": "Input",
        ],
        "zh-CN": [
            "dashboard": "仪表盘",
            "history": "历史",
            "local": "本机",
            "offline": "离线",
            "power_flow": "功率流",
            "power_usage": "电量使用情况",
            "waiting_for_data": "等待数据",
            "system_power": "系统功率",
            "charging_power": "充电功率",
            "on_battery": "电池供电",
            "fully_charged": "已充满",
            "to_full": "充满",
            "to_empty": "耗尽",
            "adapter": "适配器",
            "screen": "屏幕",
            "heatpipe": "SoC",
            "system": "整机",
            "battery_in": "电池输入",
            "battery_out": "电池输出",
            "power_loss": "损耗",
            "temperature": "温度",
            "battery_temperature": "当前电池温度",
            "battery_health": "电池健康",
            "battery_health_desc": "最大与设计容量对比",
            "cycle_count": "循环次数",
            "cycle_count_desc": "充电循环次数",
            "times": "次",
            "energy": "能量",
            "max_capacity": "最大容量",
            "loading_history": "正在加载历史…",
            "no_history": "暂无充电记录",
            "no_history_desc": "Mac 充电结束后，会话会显示在这里。",
            "select_session": "选择一个会话",
            "detail_unavailable": "详情不可用",
            "duration": "时长",
            "avg_power": "平均功率",
            "charging_rate": "充电速率",
            "charging_curve": "充电曲线",
            "additional_detail": "更多信息",
            "temperature_peak": "温度峰值",
            "adapter_power_peak": "适配器功率峰值",
            "export_json": "导出 JSON…",
            "delete": "删除",
            "with_adapter": "使用 %@",
            "peak_watts": "峰值：%.1f W",
            "avg_temp": "平均温度：%.1f°C",
            "appearance": "外观",
            "theme": "主题",
            "language": "语言",
            "animations": "动画",
            "updates_monitoring": "更新与监控",
            "update_interval": "更新间隔：%d 毫秒",
            "background_monitoring": "后台监控",
            "status_bar_item": "状态栏项目",
            "show_charging_power": "显示充电功率",
            "about": "关于",
            "version": "版本",
            "license": "许可证",
            "author": "作者",
            "repository": "代码仓库",
            "settings": "设置…",
            "about_powerflow": "关于 Powerflow",
            "hide_powerflow": "隐藏 Powerflow",
            "quit_powerflow": "退出 Powerflow",
            "show_window": "显示窗口",
            "quit": "退出",
            "chart_system": "整机",
            "chart_system_in": "系统输入",
            "chart_battery": "电池",
            "chart_screen": "屏幕",
            "chart_heatpipe": "SoC",
            "chart_input": "输入",
        ],
    ]
}

func L10n(_ key: String) -> String {
    Localization.shared.string(key)
}

func L10n(_ key: String, _ arguments: CVarArg...) -> String {
    let format = Localization.shared.string(key)
    return String(format: format, arguments: arguments)
}

private struct LocalizedEnvironment: ViewModifier {
    @Environment(AppModel.self) private var appModel

    func body(content: Content) -> some View {
        let _ = Localization.shared.setLanguage(appModel.preferences.language)
        content
    }
}

extension View {
    func localizedEnvironment() -> some View {
        modifier(LocalizedEnvironment())
    }
}
