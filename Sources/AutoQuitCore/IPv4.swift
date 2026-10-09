import Foundation

/// A single IPv4 address stored as a 32-bit integer.
public struct IPv4Address: Equatable, Hashable, Comparable, CustomStringConvertible {
    public let value: UInt32

    public init( value: UInt32 ) {
        self.value = value
    }

    /// Parses a strict dotted-quad string such as "192.168.1.23". Returns nil if invalid.
    public init?( _ string: String ) {
        let parts = string.trimmingCharacters( in: .whitespaces ).split( separator: ".", omittingEmptySubsequences: false )
        guard parts.count == 4 else { return nil }
        var result: UInt32 = 0
        for part in parts {
            guard
                !part.isEmpty,
                part.count <= 3,
                part.allSatisfy( { $0.isASCII && $0.isNumber } ),
                let octet = UInt32( part ),
                octet <= 255
            else { return nil }
            result = ( result << 8 ) | octet
        }
        value = result
    }

    public var description: String {
        "\( value >> 24 ).\( ( value >> 16 ) & 255 ).\( ( value >> 8 ) & 255 ).\( value & 255 )"
    }

    public static func < ( lhs: IPv4Address, rhs: IPv4Address ) -> Bool {
        lhs.value < rhs.value
    }
}

/// An IPv4 network: a base (network) address plus a prefix length (0...32).
public struct IPv4Network: Equatable {
    public let base: IPv4Address
    public let prefix: Int

    /// Creates a network; the address is normalised to the network address (192.168.1.57/24 -> 192.168.1.0/24).
    public init?( address: IPv4Address, prefix: Int ) {
        guard ( 0...32 ).contains( prefix ) else { return nil }
        self.prefix = prefix
        self.base = IPv4Address( value: address.value & IPv4Network.maskValue( prefix: prefix ) )
    }

    /// Parses "a.b.c.d/n".
    public init?( cidr: String ) {
        let parts = cidr.split( separator: "/", omittingEmptySubsequences: false )
        guard parts.count == 2, let address = IPv4Address( String( parts[0] ) ), let prefix = Int( parts[1] ) else { return nil }
        self.init( address: address, prefix: prefix )
    }

    /// Creates a network from an address and a subnet mask such as 255.255.255.0. Rejects non-contiguous masks.
    public init?( address: IPv4Address, mask: String ) {
        guard let prefix = IPv4Network.prefix( fromMask: mask ) else { return nil }
        self.init( address: address, prefix: prefix )
    }

    /// Converts a subnet mask string to a prefix length, or nil if it is not a contiguous mask.
    public static func prefix( fromMask mask: String ) -> Int? {
        guard let m = IPv4Address( mask ) else { return nil }
        let inverted = ~m.value
        guard inverted & ( inverted &+ 1 ) == 0 else { return nil }
        return m.value.nonzeroBitCount
    }

    static func maskValue( prefix: Int ) -> UInt32 {
        prefix == 0 ? 0 : UInt32.max << UInt32( 32 - prefix )
    }

    public var maskString: String { IPv4Address( value: IPv4Network.maskValue( prefix: prefix ) ).description }
    public var first: IPv4Address { base }
    public var last: IPv4Address { IPv4Address( value: base.value | ~IPv4Network.maskValue( prefix: prefix ) ) }
    public var count: UInt64 { UInt64( 1 ) << UInt64( 32 - prefix ) }

    public func contains( _ address: IPv4Address ) -> Bool {
        address.value & IPv4Network.maskValue( prefix: prefix ) == base.value
    }
}
