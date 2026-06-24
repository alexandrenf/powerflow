# Powerflow Swift Migration Orchestrator

This document drives the iterative migration loop to bring the **native SwiftUI app** (`Powerflow/`) to full feature parity with the legacy Rust/Tauri release.

## Repository timeline

| Era | Commits | Codebase |
|-----|---------|----------|
| **Legacy (reference)** | up to `f2e9982` (v0.2.2) | Rust/Tauri + Vue — `src-tauri/`, `crates/tpower/`, `src/` |
| **Swift (active)** | `88add38` onward | Native SwiftUI — `Powerflow/` |

**The most recent commits are Swift.** Rust lives in earlier commits only; it is the reference spec, not an active target. When comparing behavior, read the legacy implementation at the v0.2.2 baseline:

```bash
git show f2e9982:src-tauri/src/lib.rs
git show f2e9982:src-tauri/src/device.rs
git show f2e9982:crates/tpower/src/provider/mod.rs
```

The legacy files may still exist in the working tree for convenience, but **all new implementation work goes in `Powerflow/`**.

## Loop

Each iteration follows:

1. **Design** — Compare v0.2.2 Rust/Tauri behavior (git history) to current Swift
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
| iOS device attach/detach monitoring | `device.rs`, MobileDevice FFI | 🔄 Scaffold done | P0 |
| Multi-device tabs in title bar | `TitleBar.vue`, `useTab.ts` | ✅ Done | — |
| Remote iOS power polling | `remote.rs` | 🔄 Stub only | P0 |
| Remote charging history | `history.rs` (udid, is_remote) | ✅ Done | — |
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

### Iteration 2 — iOS Device Monitoring (in progress)

**Design:** Legacy uses `AMDeviceNotificationSubscribe` + `diagnostics_relay` IORegistry polling. Swift gets a `MobileDeviceBridge` ObjC layer with stub for CI, `DeviceMonitor` service, and multi-device title bar tabs.

**Specs:**
- [x] MobileDevice bridge scaffold (stub compiles without physical device)
- [x] `DeviceMonitor` service with attach/detach + polling architecture
- [x] Multi-device tabs in title bar (local + connected iPhones)
- [x] Dashboard reads from selected power source
- [x] Remote charging history saves with udid + isRemote
- [ ] Real `MobileDeviceBridge.m` implementation (replace stub on macOS device testing)
- [ ] End-to-end test with physical iPhone

**Files added:**
- `MobileDeviceBridge/` — C bridge + stub
- `Models/DeviceModels.swift`
- `Services/DeviceMonitor.swift`, `DeviceConnection.swift`, `RemotePowerDecoder.swift`

### Iteration 3 — Localization (planned)

**Specs:** Language picker switches all UI strings between en and zh-CN.

### Iteration 4 — Visual Polish (planned)

**Specs:** Chart tooltips, loading shimmer, power flow animations, app icon PNGs.

## Review Checklist (per iteration)

- [ ] All specs for the iteration marked done
- [ ] No regressions in local power monitoring
- [ ] `xcodebuild` succeeds (when run on macOS)
- [ ] Matrix above updated
