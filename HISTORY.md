# History

## 2026-10-13 – Launch at Login in Settings and menu bar click action

- Moved the Launch at Login configuration to `Sources/AutoQuit/SettingsView.swift` with a "Launch at Login" toggle and a "Quit AutoQuit" button.
- Updated `Sources/AutoQuit/MenuBarController.swift` to launch and bring the Settings window to front directly when the menu bar icon is clicked (`orderFrontRegardless`), removing the dropdown menu and menu delegate.
- Added standard macOS upper-left menu bar (`NSApp.mainMenu`) with AutoQuit, Edit, and Window menus in `Sources/AutoQuit/MenuBarController.swift`, switching activation policy to `.regular` while Settings is open and `.accessory` when closed.
- Updated `Sources/AutoQuit/LoginItem.swift` to allow toggling Launch at Login without terminating the running application.
- Added `applicationWillTerminate` in `Sources/AutoQuit/AppDelegate.swift` to unload the launchd job if the user opted out.
- Updated `scripts/build_app.sh` to stop running instances when installing, and updated `README.md`.
- Expanded Settings window dimensions to 620x760 (minimum 580x740) in `Sources/AutoQuit/SettingsView.swift` and `Sources/AutoQuit/MenuBarController.swift` to prevent content from being obscured.

## 2026-10-09 – Screenshot in README

- Added `screenshot.png` (settings window) prominently at the top of `README.md`.

## 2026-10-09 – Initial AutoQuit app (SwiftPM)

- Added `AutoQuitCore` library: IPv4 address/network math (CIDR + subnet mask), plain-English range presets and `NetworkDraft` validation, JSON `SettingsStore`, `getifaddrs` interface reader, 1 s `NetworkMonitor` (+ `NWPathMonitor`), and `EnforcementEngine` (terminate → forceTerminate at 2 s → SIGKILL at 4 s; fails closed with no network; off when unconfigured).
- Added `AutoQuit` menu bar app: custom drawn template axe icon (dot while blocking), status menu, SwiftUI settings window (pre-filled current IP, presets with live range preview, Advanced CIDR/mask entry, add/remove/drag-drop restricted apps), notifications on quit, LaunchAgent-based launch at login with relaunch on crash, single-instance guard.
- Added 17 unit tests, `scripts/build_app.sh` (ad-hoc signed `.app`, optional `--install`), `Resources/Info.plist` (`LSUIElement`), README, `.gitignore` entries.
- Swift forbids a space after prefix `!`, so `!x` is used instead of `! x` in Swift code.
- Start-at-login uses only the LaunchAgent (not `SMAppService`) to avoid double-launch; this deviates slightly from the plan.
