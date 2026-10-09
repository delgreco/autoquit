import AppKit
import SwiftUI
import AutoQuitCore

/// Owns the axe status item, its menu, and the settings window.
final class MenuBarController: NSObject, NSMenuDelegate {
    private let store: SettingsStore
    private let monitor: NetworkMonitor
    private let engine: EnforcementEngine
    private let statusItem = NSStatusBar.system.statusItem( withLength: NSStatusItem.squareLength )
    private let statusLine = NSMenuItem( title: "", action: nil, keyEquivalent: "" )
    private let loginToggle = NSMenuItem( title: "Launch at Login", action: #selector( toggleLogin ), keyEquivalent: "" )
    private var window: NSWindow?
    private var lastBlocking = false

    init( store: SettingsStore, monitor: NetworkMonitor, engine: EnforcementEngine ) {
        self.store = store
        self.monitor = monitor
        self.engine = engine
        super.init()

        statusItem.button?.image = AxeIcon.image()
        statusItem.button?.toolTip = "AutoQuit"

        let menu = NSMenu()
        menu.delegate = self
        statusLine.isEnabled = false
        menu.addItem( statusLine )
        menu.addItem( .separator() )
        let settings = NSMenuItem( title: "Settings…", action: #selector( showSettings ), keyEquivalent: "," )
        settings.target = self
        menu.addItem( settings )
        loginToggle.target = self
        menu.addItem( loginToggle )
        statusItem.menu = menu
    }

    /// Updates the icon (adds a dot while blocking). Called on every monitor tick.
    func refreshIcon() {
        let blocking = engine.state == .blocked
        if blocking != lastBlocking {
            lastBlocking = blocking
            statusItem.button?.image = AxeIcon.image( blocking: blocking )
        }
    }

    func menuNeedsUpdate( _ menu: NSMenu ) {
        let ips = monitor.addresses.map { $0.description }.joined( separator: ", " )
        switch engine.state {
            case .notConfigured: statusLine.title = "Not configured – no apps are being restricted"
            case .allowed: statusLine.title = "✅ On required network – \( ips )"
            case .blocked: statusLine.title = "⛔ Off network – restricted apps blocked\( ips.isEmpty ? "" : " (\( ips ))" )"
        }
        loginToggle.state = LoginItem.isInstalled ? .on : .off
    }

    /// Opens (or focuses) the settings window.
    @objc func showSettings() {
        if window == nil {
            let view = SettingsView( store: store, monitor: monitor )
            let hosting = NSHostingController( rootView: view )
            let window = NSWindow( contentViewController: hosting )
            window.title = "AutoQuit"
            window.styleMask = [ .titled, .closable, .miniaturizable, .resizable ]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate( ignoringOtherApps: true )
        window?.makeKeyAndOrderFront( nil )
    }

    /// Toggles launch-at-login. Turning it off also stops AutoQuit (it would otherwise be relaunched).
    @objc private func toggleLogin() {
        if LoginItem.isInstalled {
            let alert = NSAlert()
            alert.messageText = "Turn off Launch at Login?"
            alert.informativeText = "AutoQuit will quit now and restricted apps will no longer be enforced."
            alert.addButton( withTitle: "Turn Off and Quit" )
            alert.addButton( withTitle: "Cancel" )
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            LoginItem.uninstall()
            NSApp.terminate( nil )
        }
        else {
            LoginItem.install()
        }
    }
}
