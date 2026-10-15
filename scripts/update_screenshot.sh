#!/bin/bash
# Captures a native screenshot of the Settings window into screenshot.png using current settings.
set -euo pipefail
cd "$( dirname "$0" )/.."

swift build -c release
BIN_DIR="$( swift build -c release --show-bin-path )"
TMP_DIR="$( mktemp -d )"
trap 'rm -rf "$TMP_DIR"' EXIT

cat << 'SWIFT' > "$TMP_DIR/Capture.swift"
import AppKit
import SwiftUI
import AutoQuitCore

@main
struct CaptureScreenshot {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy( .regular )

        let store = SettingsStore()
        let monitor = NetworkMonitor()
        let view = SettingsView( store: store, monitor: monitor )
        let hosting = NSHostingController( rootView: view )

        let window = NSWindow( contentViewController: hosting )
        window.title = "AutoQuit"
        window.styleMask = [ .titled, .closable, .miniaturizable, .resizable ]
        window.setContentSize( NSSize( width: 620, height: 760 ) )
        window.center()
        window.makeKeyAndOrderFront( nil )
        app.activate( ignoringOtherApps: true )

        // Allow runloop time to layout and complete SwiftUI render
        RunLoop.current.run( until: Date().addingTimeInterval( 1.0 ) )

        let windowID = window.windowNumber

        let process = Process()
        process.executableURL = URL( fileURLWithPath: "/usr/sbin/screencapture" )
        process.arguments = [ "-l\( windowID )", "-o", "screenshot.png" ]
        try? process.run()
        process.waitUntilExit()
    }
}
SWIFT

swiftc -I "$BIN_DIR" "$BIN_DIR/AutoQuitCore.o" \
    Sources/AutoQuit/SettingsView.swift \
    Sources/AutoQuit/LoginItem.swift \
    "$TMP_DIR/Capture.swift" \
    -o "$TMP_DIR/capture"

"$TMP_DIR/capture"
echo "Updated screenshot.png"
