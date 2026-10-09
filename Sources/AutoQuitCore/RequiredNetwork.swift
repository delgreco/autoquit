import Foundation

/// Plain-English range choices offered to the user.
public enum RangePreset: String, Codable, CaseIterable {
    case exactAddress
    case sameLocalNetwork
    case largerNetwork
    case custom

    /// Prefix length for the preset, or nil for custom.
    public var prefix: Int? {
        switch self {
            case .exactAddress: return 32
            case .sameLocalNetwork: return 24
            case .largerNetwork: return 16
            case .custom: return nil
        }
    }

    public var title: String {
        switch self {
            case .exactAddress: return "Just this one address"
            case .sameLocalNetwork: return "My whole home/office network"
            case .largerNetwork: return "A bigger network"
            case .custom: return "Advanced"
        }
    }
}

/// The saved Required Network.
public struct RequiredNetwork: Codable, Equatable {
    public var address: String
    public var prefix: Int
    public var preset: RangePreset

    public init( address: String, prefix: Int, preset: RangePreset ) {
        self.address = address
        self.prefix = prefix
        self.preset = preset
    }

    public var network: IPv4Network? {
        guard let ip = IPv4Address( address ) else { return nil }
        return IPv4Network( address: ip, prefix: prefix )
    }

    public var summary: String { RequiredNetwork.summary( for: network ) }

    /// Human-readable description such as "192.168.1.0 – 192.168.1.255 (256 addresses)".
    public static func summary( for network: IPv4Network? ) -> String {
        guard let network = network else { return "Not a valid network" }
        if network.count == 1 {
            return "Only \( network.first ) (1 address)"
        }
        return "\( network.first ) – \( network.last ) (\( network.count.formatted() ) addresses)"
    }
}

/// What the user is typing in the network editor, and how it resolves to a network.
public struct NetworkDraft: Equatable {
    public var address: String
    public var preset: RangePreset
    /// For `.custom`: a prefix ("24" or "/24") or a subnet mask ("255.255.255.0").
    public var custom: String

    public init( address: String, preset: RangePreset = .sameLocalNetwork, custom: String = "24" ) {
        self.address = address
        self.preset = preset
        self.custom = custom
    }

    /// Resolves the draft to a network, or a friendly error message.
    public func resolve() -> Result<IPv4Network, DraftError> {
        guard let ip = IPv4Address( address ) else {
            return .failure( DraftError( message: "That isn't a valid IP address. It should look like 192.168.1.23." ) )
        }
        if let prefix = preset.prefix {
            return .success( IPv4Network( address: ip, prefix: prefix )! )
        }
        let text = custom.trimmingCharacters( in: .whitespaces )
        if text.contains( "." ) {
            guard let network = IPv4Network( address: ip, mask: text ) else {
                return .failure( DraftError( message: "That isn't a valid subnet mask. A common one is 255.255.255.0." ) )
            }
            return .success( network )
        }
        let digits = text.hasPrefix( "/" ) ? String( text.dropFirst() ) : text
        guard let prefix = Int( digits ), let network = IPv4Network( address: ip, prefix: prefix ) else {
            return .failure( DraftError( message: "Enter a size from 0 to 32 (such as /24) or a subnet mask (such as 255.255.255.0)." ) )
        }
        return .success( network )
    }
}

public struct DraftError: Error, Equatable {
    public let message: String
}
