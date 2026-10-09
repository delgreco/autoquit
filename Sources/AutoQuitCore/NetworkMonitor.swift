import Foundation
import Network
import Combine

/// Polls the Mac's IPv4 addresses every second, and also reacts instantly to system network-path changes.
public final class NetworkMonitor: ObservableObject {
    @Published public private( set ) var addresses: [IPv4Address] = []
    /// Called on the main queue after every refresh (poll or path change).
    public var onUpdate: ( ( [IPv4Address] ) -> Void )?

    private let provider: IPProvider
    private var timer: Timer?
    private let pathMonitor = NWPathMonitor()

    public init( provider: IPProvider = InterfaceReader() ) {
        self.provider = provider
    }

    /// Starts polling (1 s) and path monitoring.
    public func start( interval: TimeInterval = 1.0 ) {
        refresh()
        let timer = Timer( timeInterval: interval, repeats: true ) { [weak self] _ in self?.refresh() }
        timer.tolerance = 0.1
        RunLoop.main.add( timer, forMode: .common ) // keeps firing while menus are open
        self.timer = timer

        pathMonitor.pathUpdateHandler = { [weak self] _ in self?.refresh() }
        pathMonitor.start( queue: .main )
    }

    /// Reads the current addresses and notifies observers.
    public func refresh() {
        let current = provider.activeAddresses()
        if current != addresses {
            addresses = current
        }
        onUpdate?( current )
    }
}
