import Foundation

/// The network configuration input notation choice.
public enum NetworkNotation: String, Codable, CaseIterable {
    case cidr
    case wildcard

    public var title: String {
        switch self {
            case .cidr: return "CIDR notation"
            case .wildcard: return "Wildcard notation (asterisks)"
        }
    }
}

/// Legacy range choices offered to the user (kept for backwards compatibility).
public enum RangePreset: String, Codable, CaseIterable {
    case exactAddress
    case sameLocalNetwork
    case largerNetwork
    case custom

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
    public var notation: NetworkNotation

    public init( address: String, prefix: Int, notation: NetworkNotation = .cidr ) {
        self.address = address
        self.prefix = prefix
        self.notation = notation
    }

    /// Legacy initializer for backwards compatibility.
    public init( address: String, prefix: Int, preset: RangePreset ) {
        self.init( address: address, prefix: prefix, notation: .cidr )
    }

    public var preset: RangePreset {
        switch prefix {
            case 32: return .exactAddress
            case 24: return .sameLocalNetwork
            case 16: return .largerNetwork
            default: return .custom
        }
    }

    enum CodingKeys: String, CodingKey {
        case address, prefix, notation, preset
    }

    public init( from decoder: Decoder ) throws {
        let container = try decoder.container( keyedBy: CodingKeys.self )
        self.address = try container.decode( String.self, forKey: .address )
        self.prefix = try container.decode( Int.self, forKey: .prefix )
        if let notation = try container.decodeIfPresent( NetworkNotation.self, forKey: .notation ) {
            self.notation = notation
        }
        else {
            self.notation = .cidr
        }
    }

    public func encode( to encoder: Encoder ) throws {
        var container = encoder.container( keyedBy: CodingKeys.self )
        try container.encode( address, forKey: .address )
        try container.encode( prefix, forKey: .prefix )
        try container.encode( notation, forKey: .notation )
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
    public var notation: NetworkNotation
    public var cidrText: String
    public var wildcardText: String

    public init( notation: NetworkNotation = .cidr, cidrText: String = "", wildcardText: String = "" ) {
        self.notation = notation
        self.cidrText = cidrText
        self.wildcardText = wildcardText
    }

    public init( network: RequiredNetwork ) {
        self.notation = network.notation
        if let net = network.network {
            self.cidrText = NetworkDraft.toCIDR( network: net )
            self.wildcardText = NetworkDraft.toWildcard( network: net ) ?? network.address
        }
        else {
            self.cidrText = "\( network.address )/\( network.prefix )"
            self.wildcardText = network.address
        }
    }

    public init( detectedIP: String, notation: NetworkNotation = .cidr ) {
        self.notation = notation
        if let ip = IPv4Address( detectedIP ), let net = IPv4Network( address: ip, prefix: 24 ) {
            self.cidrText = "\( detectedIP )/24"
            self.wildcardText = NetworkDraft.toWildcard( network: net ) ?? detectedIP
        }
        else {
            self.cidrText = detectedIP.isEmpty ? "" : "\( detectedIP )/24"
            self.wildcardText = detectedIP.isEmpty ? "" : "\( detectedIP )"
        }
    }

    /// Legacy initializer for backwards compatibility.
    public init( address: String, preset: RangePreset = .sameLocalNetwork, custom: String = "24" ) {
        self.notation = .cidr
        let prefix = preset.prefix ?? ( Int( custom.hasPrefix( "/" ) ? String( custom.dropFirst() ) : custom ) ?? 24 )
        if let ip = IPv4Address( address ), let net = IPv4Network( address: ip, prefix: prefix ) {
            self.cidrText = "\( address )/\( prefix )"
            self.wildcardText = NetworkDraft.toWildcard( network: net ) ?? address
        }
        else {
            self.cidrText = "\( address )/\( prefix )"
            self.wildcardText = address
        }
    }

    public static func toWildcard( network: IPv4Network ) -> String? {
        let ip = network.base.description.split( separator: "." ).map( String.init )
        guard ip.count == 4 else { return nil }
        switch network.prefix {
            case 32:
                return network.base.description
            case 24:
                return "\( ip[0] ).\( ip[1] ).\( ip[2] ).*"
            case 16:
                return "\( ip[0] ).\( ip[1] ).*.*"
            case 8:
                return "\( ip[0] ).*.*.*"
            case 0:
                return "*.*.*.*"
            default:
                return nil
        }
    }

    public static func toCIDR( network: IPv4Network ) -> String {
        "\( network.base.description )/\( network.prefix )"
    }

    /// Resolves the draft to a network, or a friendly error message.
    public func resolve() -> Result<IPv4Network, DraftError> {
        switch notation {
            case .cidr:
                return resolveCIDR()
            case .wildcard:
                return resolveWildcard()
        }
    }

    private func resolveCIDR() -> Result<IPv4Network, DraftError> {
        let text = cidrText.trimmingCharacters( in: .whitespaces )
        if text.isEmpty {
            return .failure( DraftError( message: "Enter a CIDR network, such as 192.168.1.0/24." ) )
        }
        if text.contains( "/" ) {
            let parts = text.split( separator: "/", omittingEmptySubsequences: false )
            guard parts.count == 2 else {
                return .failure( DraftError( message: "CIDR notation must have a single '/', like 192.168.1.0/24." ) )
            }
            let ipStr = String( parts[0] ).trimmingCharacters( in: .whitespaces )
            let prefixStr = String( parts[1] ).trimmingCharacters( in: .whitespaces )
            guard let ip = IPv4Address( ipStr ) else {
                return .failure( DraftError( message: "'\( ipStr )' is not a valid IPv4 address." ) )
            }
            if prefixStr.contains( "." ) {
                guard let network = IPv4Network( address: ip, mask: prefixStr ) else {
                    return .failure( DraftError( message: "'\( prefixStr )' is not a valid subnet mask." ) )
                }
                return .success( network )
            }
            guard let prefix = Int( prefixStr ), ( 0...32 ).contains( prefix ) else {
                return .failure( DraftError( message: "Prefix must be a number from 0 to 32 (e.g. /24)." ) )
            }
            guard let network = IPv4Network( address: ip, prefix: prefix ) else {
                return .failure( DraftError( message: "Could not create network from \( text )." ) )
            }
            return .success( network )
        }

        let spaceParts = text.split( separator: " ", omittingEmptySubsequences: true )
        if spaceParts.count == 2, let ip = IPv4Address( String( spaceParts[0] ) ) {
            let maskStr = String( spaceParts[1] )
            guard let network = IPv4Network( address: ip, mask: maskStr ) else {
                return .failure( DraftError( message: "'\( maskStr )' is not a valid subnet mask." ) )
            }
            return .success( network )
        }

        if let ip = IPv4Address( text ) {
            return .success( IPv4Network( address: ip, prefix: 32 )! )
        }
        return .failure( DraftError( message: "Enter a valid CIDR network, like 192.168.1.0/24." ) )
    }

    private func resolveWildcard() -> Result<IPv4Network, DraftError> {
        let text = wildcardText.trimmingCharacters( in: .whitespaces )
        if text.isEmpty {
            return .failure( DraftError( message: "Enter a wildcard address, such as 192.168.1.* or 10.*.*.*." ) )
        }
        if text.contains( "/" ) {
            return .failure( DraftError( message: "Wildcard notation uses asterisks (e.g. 192.168.1.*), not slashes." ) )
        }
        var parts = text.split( separator: ".", omittingEmptySubsequences: false ).map { String( $0 ).trimmingCharacters( in: .whitespaces ) }
        if parts.last == "*" && parts.count < 4 {
            while parts.count < 4 {
                parts.append( "*" )
            }
        }
        guard parts.count == 4 else {
            return .failure( DraftError( message: "Wildcard notation should have 4 octets separated by dots, such as 192.168.1.*." ) )
        }
        var seenWildcard = false
        var prefix = 32
        var octets: [UInt32] = []
        for ( index, part ) in parts.enumerated() {
            if part == "*" {
                if !seenWildcard {
                    seenWildcard = true
                    prefix = index * 8
                }
                octets.append( 0 )
            }
            else {
                if seenWildcard {
                    return .failure( DraftError( message: "Wildcard (*) octets must appear at the end, like 192.168.1.*." ) )
                }
                guard
                    !part.isEmpty,
                    part.count <= 3,
                    part.allSatisfy( { $0.isASCII && $0.isNumber } ),
                    let num = UInt32( part ),
                    num <= 255
                else {
                    return .failure( DraftError( message: "'\( part )' is not a valid octet. Octets must be 0–255 or '*'." ) )
                }
                octets.append( num )
            }
        }
        let value = ( octets[0] << 24 ) | ( octets[1] << 16 ) | ( octets[2] << 8 ) | octets[3]
        let ip = IPv4Address( value: value )
        guard let network = IPv4Network( address: ip, prefix: prefix ) else {
            return .failure( DraftError( message: "Could not create network from wildcard." ) )
        }
        return .success( network )
    }
}

public struct DraftError: Error, Equatable {
    public let message: String
}
