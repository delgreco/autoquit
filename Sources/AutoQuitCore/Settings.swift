import Foundation
import Combine

/// An app the user has restricted to the Required Network.
public struct RestrictedApp: Codable, Equatable, Identifiable {
    public var bundleID: String
    public var name: String
    public var path: String

    public var id: String { bundleID }

    public init( bundleID: String, name: String, path: String ) {
        self.bundleID = bundleID
        self.name = name
        self.path = path
    }

    /// Builds a RestrictedApp from an .app bundle URL, or nil if it has no bundle identifier.
    public init?( url: URL ) {
        guard let bundle = Bundle( url: url ), let bundleID = bundle.bundleIdentifier else { return nil }
        let name = ( bundle.object( forInfoDictionaryKey: "CFBundleDisplayName" ) as? String )
            ?? ( bundle.object( forInfoDictionaryKey: "CFBundleName" ) as? String )
            ?? url.deletingPathExtension().lastPathComponent
        self.init( bundleID: bundleID, name: name, path: url.path )
    }
}

public struct Settings: Codable, Equatable {
    public var requiredNetwork: RequiredNetwork?
    public var restrictedApps: [RestrictedApp] = []

    public init( requiredNetwork: RequiredNetwork? = nil, restrictedApps: [RestrictedApp] = [] ) {
        self.requiredNetwork = requiredNetwork
        self.restrictedApps = restrictedApps
    }
}

/// Observable, JSON-backed settings store (atomic writes).
public final class SettingsStore: ObservableObject {
    @Published public private(set) var settings: Settings
    private let fileURL: URL

    public static var defaultURL: URL {
        let base = FileManager.default.urls( for: .applicationSupportDirectory, in: .userDomainMask )[0]
        return base.appendingPathComponent( "AutoQuit/settings.json" )
    }

    public init( fileURL: URL = SettingsStore.defaultURL ) {
        self.fileURL = fileURL
        if let data = try? Data( contentsOf: fileURL ), let loaded = try? JSONDecoder().decode( Settings.self, from: data ) {
            settings = loaded
        }
        else {
            settings = Settings()
        }
    }

    /// Applies a mutation, publishes it, and persists it atomically.
    public func update( _ change: ( inout Settings ) -> Void ) {
        var copy = settings
        change( &copy )
        guard copy != settings else { return }
        settings = copy
        save()
    }

    private func save() {
        do {
            try FileManager.default.createDirectory( at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [ .prettyPrinted, .sortedKeys ]
            try encoder.encode( settings ).write( to: fileURL, options: .atomic )
        }
        catch {
            NSLog( "AutoQuit: failed to save settings: \( error )" )
        }
    }
}
