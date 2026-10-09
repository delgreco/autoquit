# AutoQuit

A macOS menu bar app (axe icon) that quits chosen apps whenever your Mac is not on a "Required Network".

- Starts at login via a per-user LaunchAgent (`~/Library/LaunchAgents/com.autoquit.app.plist`) and is relaunched if killed.
- Polls IPv4 addresses every second (plus instant reaction to network changes).
- Restricted apps are quit immediately; if they resist they are force-quit after 2 s and `SIGKILL`ed after 4 s. Apps launched while off-network are quit too.
- Enforcement is **off** until a Required Network is saved. With no network at all, restricted apps are blocked.

## Build / test

```
swift test
scripts/build_app.sh             # builds build/AutoQuit.app (ad-hoc signed)
scripts/build_app.sh --install   # also copies to ~/Applications and launches it
```

Run it from its final location (`~/Applications`): the LaunchAgent records the path of the executable that first ran.
To stop AutoQuit, use the menu item **Launch at Login** to turn it off (this quits the app).

Settings live in `~/Library/Application Support/AutoQuit/settings.json`.
