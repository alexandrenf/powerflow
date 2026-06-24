# Powerflow Swift Migration Orchestrator

This document drives the iterative migration loop from the legacy Rust/Tauri app (`src-tauri/`, `crates/tpower/`) to the native SwiftUI app (`Powerflow/`).

## Loop

Each iteration follows:

1. **Design** — Compare legacy behavior to Swift implementation
2. **Specs** — Write acceptance criteria for the gap
3. **Implementation plan** — Ordered tasks with file targets
4. **Implement** — Code changes on `cursor/swift-migration-orchestrator-c5e1`
5. **Review** — Verify against specs; update status below

## Feature Parity Matrix

| Feature | Legacy (Rust/Tauri) | Swift Status | Priority |
|---------|---------------------|--------------|----------|
| Local Mac SMC + IORegistry monitoring | `local.rs`, `tpower/` | ✅ Done | — |
| Menu bar status item + watt title | `tray_icon.rs` | ✅ Done | — |
| Menu bar popover | `Popover.vue` | ✅ Done | — |
| Menu bar right-click: Show / Quit | `tray_icon.rs` | ✅ Done | — |
| Close main window → hide (accessory mode) | `lib.rs` window event | ✅ Done | — |
| Settings window opens reliably | `open_settings` command | ✅ Done | — |
| Dashboard power status card | `PowerStatus.vue` | ✅ Done | — |
| Power flow diagram | `PowerFlow.vue` | ✅ Partial (no shimmer) | P3 |
| Live power chart (dynamic series) | `PowerUsageChart.vue` | ✅ Done | — |
| Technical detail cards | `TechnicalDetail.vue` | ✅ Done | — |
| Charging history (local) | `history.rs`, `History.vue` | ✅ Done | — |
| History live refresh on new session | `HistoryRecordedEvent` | ✅ Done | — |
| Settings: theme, interval, status bar | `Settings.vue` | ✅ Done | — |
| Settings: language (en/zh-CN) | `locales/` + vue-i18n | ❌ Picker only | P3 |
| Settings: animations toggle | `preference.ts` | ⚠️ Partial (watts only) | P3 |
| iOS device attach/detach monitoring | `device.rs`, MobileDevice FFI | ❌ Not started | P0 |
| Multi-device tabs in title bar | `TitleBar.vue`, `useTab.ts` | ❌ Not started | P0 |
| Remote iOS power polling | `remote.rs` | ❌ Not started | P0 |
| Remote charging history | `history.rs` (udid, is_remote) | ❌ UI only | P0 |
| App menu (About, Hide, Quit) | `menu.rs` | ❌ Missing | P2 |
| App icon assets | bundle | ❌ PNGs missing | P3 |
| Chart tooltips | `CustomChartTooltip.vue` | ❌ Missing | P3 |
| Loading shimmer/skeleton | `Shimmer.vue` | ❌ Missing | P3 |

## Iteration Log

### Iteration 1 — UI Cohesion (current)

**Design:** The Swift app has core local monitoring but menu-bar app behaviors and settings navigation are incomplete. Users expect close-to-tray, right-click quit, and a working gear/Cmd+, settings path matching legacy.

**Specs:**
- [x] Gear button and Cmd+, open the Settings window every time
- [x] Closing the main window hides it and sets accessory activation policy
- [x] Right-clicking the menu bar icon shows Show Window / Quit
- [x] Live chart shows Screen + Heatpipe when on battery; System In when charging
- [x] History list refreshes when a new charging session is recorded

**Implementation plan:**
1. `AppNotifications.swift` — shared notification names
2. `SettingsOpener.swift` — bridge `AppModel` → `@Environment(\.openSettings)`
3. `WindowLifecycle.swift` — intercept close → `hideMainWindow()`
4. `StatusBarController.swift` — right-click menu
5. `PowerModels.swift` / `PowerMonitor.swift` — extend `StatisticPoint`
6. `DashboardView.swift` — dynamic chart series
7. `ChargingHistoryRecorder.swift` — post history-recorded notification

### Iteration 2 — iOS Device Monitoring (planned)

**Design:** Legacy uses `AMDeviceNotificationSubscribe` + `diagnostics_relay` over the private MobileDevice framework. Swift needs a thin C/ObjC bridge module.

**Specs:**
- Device attach/detach events update title bar tabs
- Per-device power polling at configured interval
- Remote `NormalizedResource` with `isLocal: false`
- Remote sessions saved to charging history with udid

**Implementation plan:**
1. `MobileDevice/` — FFI bridge (mirror `crates/tpower/src/ffi/`)
2. `DeviceMonitor.swift` — notification loop + polling
3. `AppModel.swift` — multi-device state
4. `MainWindowView.swift` — device tabs like legacy `TitleBar.vue`

### Iteration 3 — Localization (planned)

**Specs:** Language picker switches all UI strings between en and zh-CN.

### Iteration 4 — Visual Polish (planned)

**Specs:** Chart tooltips, loading shimmer, power flow animations, app icon PNGs.

## Review Checklist (per iteration)

- [ ] All specs for the iteration marked done
- [ ] No regressions in local power monitoring
- [ ] `xcodebuild` succeeds (when run on macOS)
- [ ] Matrix above updated
