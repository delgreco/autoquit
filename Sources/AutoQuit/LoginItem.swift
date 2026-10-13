import Foundation

/// Installs / removes a per-user LaunchAgent so AutoQuit starts at login and is relaunched if it dies.
enum LoginItem {
    static let label = "com.autoquit.app"
    private static let optOutKey = "launchAtLoginOptOut"

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent( "Library/LaunchAgents/\( label ).plist" )
    }

    static var isInstalled: Bool { FileManager.default.fileExists( atPath: plistURL.path ) }
    static var userOptedOut: Bool { UserDefaults.standard.bool( forKey: optOutKey ) }

    /// Writes the LaunchAgent plist file.
    @discardableResult
    static func writePlist() -> Bool {
        guard let executable = Bundle.main.executablePath else { return false }
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [ executable ],
            "RunAtLoad": true,
            "KeepAlive": [ "SuccessfulExit": false ],
            "ProcessType": "Interactive",
            "LimitLoadToSessionType": "Aqua",
        ]
        do {
            try FileManager.default.createDirectory( at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true )
            ( plist as NSDictionary ).write( to: plistURL, atomically: true )
            UserDefaults.standard.set( false, forKey: optOutKey )
            return true
        }
        catch {
            return false
        }
    }

    /// Writes the LaunchAgent plist and loads it. KeepAlive only on non-zero exit so a duplicate instance that
    /// exits cleanly is not relaunched, but a crash or `kill -9` is.
    @discardableResult
    static func install() -> Bool {
        guard writePlist() else { return false }
        _ = launchctl( [ "bootout", domain + "/" + label ] )
        return launchctl( [ "bootstrap", domain, plistURL.path ] )
    }

    /// Deletes the LaunchAgent plist and records opt-out so AutoQuit does not start at login.
    static func uninstall() {
        UserDefaults.standard.set( true, forKey: optOutKey )
        try? FileManager.default.removeItem( at: plistURL )
    }

    /// Unloads the job from launchd.
    static func bootout() {
        _ = launchctl( [ "bootout", domain + "/" + label ] )
    }

    private static var domain: String { "gui/\( getuid() )" }

    private static func launchctl( _ arguments: [String] ) -> Bool {
        let process = Process()
        process.executableURL = URL( fileURLWithPath: "/bin/launchctl" )
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        }
        catch {
            return false
        }
    }
}
