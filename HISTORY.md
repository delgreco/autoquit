# History

## 2026-10-09 – Screenshot in README

- Added `screenshot.png` (settings window) prominently at the top of `README.md`.

## 2026-10-09 – Initial AutoQuit app (SwiftPM)

- Added `AutoQuitCore` library: IPv4 address/network math (CIDR + subnet mask), plain-English range presets and `NetworkDraft` validation, JSON `SettingsStore`, `getifaddrs` interface reader, 1 s `NetworkMonitor` (+ `NWPathMonitor`), and `EnforcementEngine` (terminate → forceTerminate at 2 s → SIGKILL at 4 s; fails closed with no network; off when unconfigured).
- Added `AutoQuit` menu bar app: custom drawn template axe icon (dot while blocking), status menu, SwiftUI settings window (pre-filled current IP, presets with live range preview, Advanced CIDR/mask entry, add/remove/drag-drop restricted apps), notifications on quit, LaunchAgent-based launch at login with relaunch on crash, single-instance guard.
- Added 17 unit tests, `scripts/build_app.sh` (ad-hoc signed `.app`, optional `--install`), `Resources/Info.plist` (`LSUIElement`), README, `.gitignore` entries.
- Swift forbids a space after prefix `!`, so `!x` is used instead of `! x` in Swift code.
- Start-at-login uses only the LaunchAgent (not `SMAppService`) to avoid double-launch; this deviates slightly from the plan.
