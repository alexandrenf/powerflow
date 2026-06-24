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

The legacy files may still exist in the working tree for convenience, but **all new implementation work goes in `Powerflow/`.

## Loop

Each iteration follows:

1. **Design** — Compare v0.2.2 Rust/Tauri behavior (git history) to current Swift
2. **Specs** — Write acceptance criteria for the gap
3. **Implementation plan** — Ordered tasks with file targets
4. **Implement** — Code changes on `cursor/swift-migration-orchestrator-c5e1`
5. **Review** — Verify against specs; update status below

**Current iteration:** 6 (animations polish — planned)

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
| Power flow diagram | `PowerFlow.vue` | ✅ Done | P3 |
| Live power chart (dynamic series) | `PowerUsageChart.vue` | ✅ Done | — |
| Technical detail cards | `TechnicalDetail.vue` | ✅ Done | — |
| Charging history (local) | `history.rs`, `History.vue` | ✅ Done | — |
| History live refresh on new session | `HistoryRecordedEvent` | ✅ Done | — |
| Settings: theme, interval, status bar | `Settings.vue` | ✅ Done | — |
| Settings: language (en/zh-CN) | `locales/` + vue-i18n | ✅ Done | — |
| Settings: animations toggle | `preference.ts` | ⚠️ Partial (watts only) | P3 |
| iOS device attach/detach monitoring | `device.rs`, MobileDevice FFI | ✅ Bridge done | — |
| Multi-device tabs in title bar | `TitleBar.vue`, `useTab.ts` | ✅ Done | — |
| Remote iOS power polling | `remote.rs` | ✅ Bridge done | — |
| Remote charging history | `history.rs` (udid, is_remote) | ✅ Done | — |
| App menu (About, Hide, Quit) | `menu.rs` | ✅ Done | — |
| App icon assets | bundle | ✅ Done (in 88add38) | — |
| Chart tooltips | `CustomChartTooltip.vue` | ❌ Missing | P3 |
| Loading shimmer/skeleton | `Shimmer.vue` | ✅ Done | — |

## Iteration Log

### Iteration 1 — UI Cohesion ✅

**Design:** Menu-bar app behaviors and settings navigation incomplete vs v0.2.2.

**Specs:** Settings open, close-to-tray, status bar menu, dynamic chart, history refresh — all done.

**Review:** Passed.

### Iteration 2 — iOS Device Monitoring ✅

**Design:** Legacy `AMDeviceNotificationSubscribe` + `diagnostics_relay` IORegistry polling via private MobileDevice framework.

**Specs:**
- [x] MobileDevice bridge scaffold
- [x] `DeviceMonitor` attach/detach + polling
- [x] Multi-device title bar tabs
- [x] Dashboard reads selected power source
- [x] Remote charging history with udid + isRemote
- [x] Real `MobileDeviceBridge.m` via dlopen (no static link required)
- [ ] End-to-end test with physical iPhone (manual, on macOS)

**Review:** Code complete; physical device test pending manual verification.

### Iteration 3 — Localization ✅

**Design:** Legacy uses `locales/en.yaml` and `locales/zh-CN.yaml` with vue-i18n.

**Specs:**
- [x] Language picker switches UI strings at runtime
- [x] en + zh-CN coverage for dashboard, history, settings, menu bar

**Files:** `Support/Localization.swift`, view string updates.

**Review:** Passed.

### Iteration 4 — App Menu + Loading Shimmer ✅

**Design:** Legacy `menu.rs` provides About, Preferences, Hide, Quit. Legacy `Shimmer.vue` for loading states.

**Specs:**
- [x] About Powerflow menu item
- [x] Hide / Quit commands
- [x] Shimmer placeholder while power data loads

**Review:** Passed.

### Iteration 5 — Chart Tooltips (planned)

**Design:** Legacy `CustomChartTooltip.vue` shows values on hover for chart series.

**Specs:**
- [ ] Hover tooltip on live power chart showing series name + watts
- [ ] Hover tooltip on history charging curve

## Review Checklist (per iteration)

- [x] Iterations 1–4 specs marked done
- [ ] No regressions in local power monitoring (manual macOS test)
- [ ] `xcodebuild` succeeds (manual macOS test)
- [x] Matrix above updated
