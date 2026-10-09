import AppKit
import UserNotifications
import Combine
import AutoQuitCore

/// Wires the monitor, engine, menu bar, notifications, and login item together.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = SettingsStore()
    private let monitor = NetworkMonitor()
    private lazy var engine = EnforcementEngine( store: store )
    private var menuBar: MenuBarController?
    private var activity: NSObjectProtocol?

    func applicationDidFinishLaunching( _ notification: Notification ) {
        guard ensureSingleInstance() else {
            exit( 0 )
        }

        // Install the LaunchAgent on first run; the launchd-managed copy takes over from this one.
        if !LoginItem.userOptedOut && !LoginItem.isInstalled && LoginItem.install() {
            exit( 0 )
        }

        // Keep timers running at full rate even when idle (no App Nap).
        activity = ProcessInfo.processInfo.beginActivity( options: [ .userInitiatedAllowingIdleSystemSleep ], reason: "Monitoring network" )

        UNUserNotificationCenter.current().requestAuthorization( options: [ .alert ] ) { _, _ in }
        engine.onQuit = { target in
            let content = UNMutableNotificationContent()
            content.title = "AutoQuit quit \( target.name )"
            content.body = "You're not on your required network."
            UNUserNotificationCenter.current().add( UNNotificationRequest( identifier: UUID().uuidString, content: content, trigger: nil ) )
        }

        let menuBar = MenuBarController( store: store, monitor: monitor, engine: engine )
        self.menuBar = menuBar

        monitor.onUpdate = { [weak self] addresses in
            guard let self = self else { return }
            self.engine.evaluate( addresses: addresses )
            self.menuBar?.refreshIcon()
        }
        // Re-evaluate immediately on settings edits and when any app launches.
        store.objectWillChange.receive( on: DispatchQueue.main ).sink { [weak self] in self?.monitor.refresh() }.store( in: &cancellables )
        NSWorkspace.shared.notificationCenter.addObserver( forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main ) { [weak self] _ in
            self?.monitor.refresh()
        }
        monitor.start()

        // First run with nothing configured: open Settings so setup is obvious.
        if store.settings.requiredNetwork == nil {
            menuBar.showSettings()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed( _ sender: NSApplication ) -> Bool { false }

    private var cancellables = Set<AnyCancellable>()

    /// Waits briefly for a previous instance (e.g. the one that just installed the LaunchAgent) to exit.
    private func ensureSingleInstance() -> Bool {
        guard let id = Bundle.main.bundleIdentifier else { return true }
        let me = ProcessInfo.processInfo.processIdentifier
        for _ in 0..<50 {
            if NSRunningApplication.runningApplications( withBundleIdentifier: id ).allSatisfy( { $0.processIdentifier == me } ) {
                return true
            }
            Thread.sleep( forTimeInterval: 0.1 )
        }
        return false
    }
}
