import Foundation
import AppKit

/// Overall enforcement state.
public enum EnforcementState: Equatable {
    case notConfigured
    case allowed
    case blocked
}

/// Pure decision logic: no side effects.
public enum Policy {
    /// Not configured -> enforcement off. Configured -> allowed only if ANY active IP is in the network.
    /// With no active IPs at all this fails closed (blocked).
    public static func state( addresses: [IPv4Address], required: RequiredNetwork? ) -> EnforcementState {
        guard let network = required?.network else { return .notConfigured }
        return addresses.contains( where: { network.contains( $0 ) } ) ? .allowed : .blocked
    }
}

/// A running process matching a restricted app.
public struct RunningTarget: Equatable {
    public let pid: Int32
    public let bundleID: String
    public let name: String

    public init( pid: Int32, bundleID: String, name: String ) {
        self.pid = pid
        self.bundleID = bundleID
        self.name = name
    }
}

/// Process control, abstracted so the engine can be tested.
public protocol ProcessController {
    func runningTargets( bundleIDs: Set<String> ) -> [RunningTarget]
    func terminate( pid: Int32 )
    func forceTerminate( pid: Int32 )
    func kill( pid: Int32 )
}

/// Real implementation backed by NSRunningApplication and kill(2).
public struct SystemProcessController: ProcessController {
    public init() {}

    public func runningTargets( bundleIDs: Set<String> ) -> [RunningTarget] {
        NSWorkspace.shared.runningApplications.compactMap { app in
            guard let id = app.bundleIdentifier, bundleIDs.contains( id ) else { return nil }
            return RunningTarget( pid: app.processIdentifier, bundleID: id, name: app.localizedName ?? id )
        }
    }

    public func terminate( pid: Int32 ) { NSRunningApplication( processIdentifier: pid )?.terminate() }
    public func forceTerminate( pid: Int32 ) { NSRunningApplication( processIdentifier: pid )?.forceTerminate() }
    public func kill( pid: Int32 ) { _ = Darwin.kill( pid, SIGKILL ) }
}

/// Quits restricted apps whenever the Mac is off the Required Network.
/// Escalation per process: terminate at once, forceTerminate after `forceAfter`, SIGKILL after `killAfter`.
public final class EnforcementEngine {
    public private( set ) var state: EnforcementState = .notConfigured
    /// Called once per process the first time it is told to quit (for notifications).
    public var onQuit: ( ( RunningTarget ) -> Void )?

    private let store: SettingsStore
    private let controller: ProcessController
    private let now: () -> Date
    private let forceAfter: TimeInterval
    private let killAfter: TimeInterval
    private var firstAttempt: [Int32: Date] = [:]

    public init(
        store: SettingsStore,
        controller: ProcessController = SystemProcessController(),
        forceAfter: TimeInterval = 2,
        killAfter: TimeInterval = 4,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.controller = controller
        self.forceAfter = forceAfter
        self.killAfter = killAfter
        self.now = now
    }

    /// Evaluates the policy for the given addresses and quits restricted apps if blocked. Safe to call often.
    @discardableResult
    public func evaluate( addresses: [IPv4Address] ) -> EnforcementState {
        let settings = store.settings
        state = Policy.state( addresses: addresses, required: settings.requiredNetwork )

        guard state == .blocked else {
            firstAttempt.removeAll()
            return state
        }

        let targets = controller.runningTargets( bundleIDs: Set( settings.restrictedApps.map { $0.bundleID } ) )
        let livePIDs = Set( targets.map { $0.pid } )
        firstAttempt = firstAttempt.filter { livePIDs.contains( $0.key ) }

        for target in targets {
            if let started = firstAttempt[ target.pid ] {
                let elapsed = now().timeIntervalSince( started )
                if elapsed >= killAfter {
                    controller.kill( pid: target.pid )
                }
                else if elapsed >= forceAfter {
                    controller.forceTerminate( pid: target.pid )
                }
            }
            else {
                firstAttempt[ target.pid ] = now()
                controller.terminate( pid: target.pid )
                onQuit?( target )
            }
        }
        return state
    }
}
