import AppKit
import SwiftUI
import AutoQuitCore

/// Owns the axe status item and the settings window.
final class MenuBarController: NSObject, NSWindowDelegate {
    private let store: SettingsStore
    private let monitor: NetworkMonitor
    private let engine: EnforcementEngine
    private let statusItem = NSStatusBar.system.statusItem( withLength: NSStatusItem.squareLength )
    private var window: NSWindow?
    private var lastBlocking = false

    init( store: SettingsStore, monitor: NetworkMonitor, engine: EnforcementEngine ) {
        self.store = store
        self.monitor = monitor
        self.engine = engine
        super.init()

        setupMainMenu()

        if let button = statusItem.button {
            button.image = AxeIcon.image()
            button.toolTip = "AutoQuit"
            button.target = self
            button.action = #selector( showSettings )
        }
    }

    /// Builds the standard macOS menu bar displayed at the upper left when active.
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // Application Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem( withTitle: "About AutoQuit", action: #selector( NSApplication.orderFrontStandardAboutPanel( _: ) ), keyEquivalent: "" )
        appMenu.addItem( .separator() )
        let settingsItem = NSMenuItem( title: "Settings…", action: #selector( showSettings ), keyEquivalent: "," )
        settingsItem.target = self
        appMenu.addItem( settingsItem )
        appMenu.addItem( .separator() )
        let servicesItem = NSMenuItem( title: "Services", action: nil, keyEquivalent: "" )
        let servicesMenu = NSMenu()
        servicesItem.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        appMenu.addItem( servicesItem )
        appMenu.addItem( .separator() )
        appMenu.addItem( withTitle: "Hide AutoQuit", action: #selector( NSApplication.hide( _: ) ), keyEquivalent: "h" )
        let hideOthers = NSMenuItem( title: "Hide Others", action: #selector( NSApplication.hideOtherApplications( _: ) ), keyEquivalent: "h" )
        hideOthers.keyEquivalentModifierMask = [ .command, .option ]
        appMenu.addItem( hideOthers )
        appMenu.addItem( withTitle: "Show All", action: #selector( NSApplication.unhideAllApplications( _: ) ), keyEquivalent: "" )
        appMenu.addItem( .separator() )
        appMenu.addItem( withTitle: "Quit AutoQuit", action: #selector( NSApplication.terminate( _: ) ), keyEquivalent: "q" )
        appMenuItem.submenu = appMenu
        mainMenu.addItem( appMenuItem )

        // Edit Menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu( title: "Edit" )
        editMenu.addItem( withTitle: "Undo", action: Selector(( "undo:" )), keyEquivalent: "z" )
        let redoItem = NSMenuItem( title: "Redo", action: Selector(( "redo:" )), keyEquivalent: "Z" )
        editMenu.addItem( redoItem )
        editMenu.addItem( .separator() )
        editMenu.addItem( withTitle: "Cut", action: #selector( NSText.cut( _: ) ), keyEquivalent: "x" )
        editMenu.addItem( withTitle: "Copy", action: #selector( NSText.copy( _: ) ), keyEquivalent: "c" )
        editMenu.addItem( withTitle: "Paste", action: #selector( NSText.paste( _: ) ), keyEquivalent: "v" )
        editMenu.addItem( withTitle: "Select All", action: #selector( NSText.selectAll( _: ) ), keyEquivalent: "a" )
        editMenuItem.submenu = editMenu
        mainMenu.addItem( editMenuItem )

        // Window Menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu( title: "Window" )
        windowMenu.addItem( withTitle: "Close", action: #selector( NSWindow.performClose( _: ) ), keyEquivalent: "w" )
        windowMenu.addItem( withTitle: "Minimize", action: #selector( NSWindow.performMiniaturize( _: ) ), keyEquivalent: "m" )
        windowMenu.addItem( withTitle: "Zoom", action: #selector( NSWindow.performZoom( _: ) ), keyEquivalent: "" )
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem( windowMenuItem )
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }

    /// Updates the icon (adds a dot while blocking). Called on every monitor tick.
    func refreshIcon() {
        let blocking = engine.state == .blocked
        if blocking != lastBlocking {
            lastBlocking = blocking
            statusItem.button?.image = AxeIcon.image( blocking: blocking )
        }
    }

    /// Opens (or focuses) the settings window and activates the app.
    @objc func showSettings( _ sender: Any? = nil ) {
        NSApp.setActivationPolicy( .regular )
        if window == nil {
            let view = SettingsView( store: store, monitor: monitor )
            let hosting = NSHostingController( rootView: view )
            let window = NSWindow( contentViewController: hosting )
            window.title = "AutoQuit"
            window.styleMask = [ .titled, .closable, .miniaturizable, .resizable ]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.setContentSize( NSSize( width: 620, height: 760 ) )
            window.center()
            self.window = window
        }
        NSApp.activate( ignoringOtherApps: true )
        window?.makeKeyAndOrderFront( nil )
        window?.orderFrontRegardless()
    }

    func windowWillClose( _ notification: Notification ) {
        NSApp.setActivationPolicy( .accessory )
    }
}
