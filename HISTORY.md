# History

## 2026-10-14 – CIDR and Wildcard network configuration choices

- Replaced preset radio choices in `Sources/AutoQuit/SettingsView.swift` with two distinct notation options: "CIDR notation" (e.g. `192.168.1.0/24`) and "Wildcard notation (asterisks)" (e.g. `192.168.1.*`, `192.168.*.*`, `10.*.*.*`).
- Added `NetworkNotation` enum in `Sources/AutoQuitCore/RequiredNetwork.swift` and updated `RequiredNetwork` and `NetworkDraft` to parse, validate, and convert between CIDR and wildcard asterisk notation while maintaining backwards compatibility with existing stored settings.
- Updated `Tests/AutoQuitTests/AutoQuitTests.swift` with unit tests for CIDR notation, Wildcard notation, conversions, and error reporting.

## 2026-10-14 – Colored status dot on menu bar icon

- Updated `Sources/AutoQuit/AxeIcon.swift` to support colored status dots (`NSColor.systemRed` when off network / blocked, `NSColor.systemGreen` when on allowed network), dynamically adapting axe haft and blade colors to macOS Light/Dark appearances while retaining non-template color reproduction for the dot.
- Updated `Sources/AutoQuit/MenuBarController.swift` to track `EnforcementState` and show a red dot when blocked, a green dot when allowed on the required network, and no dot when unconfigured.

## 2026-10-13 – Launch at Login in Settings and menu bar click action

- Moved the Launch at Login configuration to `Sources/AutoQuit/SettingsView.swift` with a "Launch at Login" toggle and a "Quit AutoQuit" button.
- Updated `Sources/AutoQuit/MenuBarController.swift` to launch and bring the Settings window to front directly when the menu bar icon is clicked (`orderFrontRegardless`), removing the dropdown menu and menu delegate.
- Added standard macOS upper-left menu bar (`NSApp.mainMenu`) with AutoQuit, Edit, and Window menus in `Sources/AutoQuit/MenuBarController.swift`, switching activation policy to `.regular` while Settings is open and `.accessory` when closed.
- Updated `Sources/AutoQuit/LoginItem.swift` to allow toggling Launch at Login without terminating the running application.
- Added `applicationWillTerminate` in `Sources/AutoQuit/AppDelegate.swift` to unload the launchd job if the user opted out.
- Updated `scripts/build_app.sh` to stop running instances when installing, and updated `README.md`.
- Expanded Settings window dimensions to 620x760 (minimum 580x740) in `Sources/AutoQuit/SettingsView.swift` and `Sources/AutoQuit/MenuBarController.swift` to prevent content from being obscured.
- Redrew menu bar axe icon in `Sources/AutoQuit/AxeIcon.swift` with authentic woodsman axe geometry (curved haft, flat hammer poll, eye, and bearded cutting edge).
- Created full-size macOS application icon (`Resources/AppIcon.icns` and `Resources/AppIcon.png`) based on the axe design in a dark slate squircle tile, and configured `CFBundleIconFile` in `Resources/Info.plist` and `scripts/build_app.sh`.

## 2026-10-09 – Screenshot in README

- Added `screenshot.png` (settings window) prominently at the top of `README.md`.

## 2026-10-09 – Initial AutoQuit app (SwiftPM)

- Added `AutoQuitCore` library: IPv4 address/network math (CIDR + subnet mask), plain-English range presets and `NetworkDraft` validation, JSON `SettingsStore`, `getifaddrs` interface reader, 1 s `NetworkMonitor` (+ `NWPathMonitor`), and `EnforcementEngine` (terminate → forceTerminate at 2 s → SIGKILL at 4 s; fails closed with no network; off when unconfigured).
- Added `AutoQuit` menu bar app: custom drawn template axe icon (dot while blocking), status menu, SwiftUI settings window (pre-filled current IP, presets with live range preview, Advanced CIDR/mask entry, add/remove/drag-drop restricted apps), notifications on quit, LaunchAgent-based launch at login with relaunch on crash, single-instance guard.
- Added 17 unit tests, `scripts/build_app.sh` (ad-hoc signed `.app`, optional `--install`), `Resources/Info.plist` (`LSUIElement`), README, `.gitignore` entries.
- Swift forbids a space after prefix `!`, so `!x` is used instead of `! x` in Swift code.
- Start-at-login uses only the LaunchAgent (not `SMAppService`) to avoid double-launch; this deviates slightly from the plan.
