import Foundation
import Darwin

/// Supplies the Mac's current IPv4 addresses.
public protocol IPProvider {
    func activeAddresses() -> [IPv4Address]
}

/// Reads IPv4 addresses via getifaddrs, skipping loopback and link-local addresses.
public struct InterfaceReader: IPProvider {
    public init() {}

    /// Returns ( interface name, address ) for every UP, non-loopback, non-link-local IPv4 interface.
    public func interfaces() -> [ ( name: String, address: IPv4Address ) ] {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs( &head ) == 0, let first = head else { return [] }
        defer { freeifaddrs( head ) }

        var result: [ ( name: String, address: IPv4Address ) ] = []
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = cursor {
            defer { cursor = entry.pointee.ifa_next }
            let flags = Int32( entry.pointee.ifa_flags )
            guard
                flags & IFF_UP != 0,
                flags & IFF_LOOPBACK == 0,
                let sa = entry.pointee.ifa_addr,
                sa.pointee.sa_family == UInt8( AF_INET )
            else { continue }

            let value = sa.withMemoryRebound( to: sockaddr_in.self, capacity: 1 ) { UInt32( bigEndian: $0.pointee.sin_addr.s_addr ) }
            let address = IPv4Address( value: value )
            if address.value >> 16 == 0xA9FE { continue } // 169.254.x.x link-local
            result.append( ( name: String( cString: entry.pointee.ifa_name ), address: address ) )
        }
        return result
    }

    public func activeAddresses() -> [IPv4Address] {
        interfaces().map { $0.address }
    }

    /// Best guess at "my" IP for pre-populating the editor: prefers en0, then the first interface.
    public func currentPrimaryIP() -> IPv4Address? {
        let all = interfaces()
        return all.first( where: { $0.name == "en0" } )?.address ?? all.first?.address
    }
}
