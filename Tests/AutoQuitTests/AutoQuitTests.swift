import XCTest
@testable import AutoQuitCore

final class IPv4Tests: XCTestCase {
    func testParseValid() {
        XCTAssertEqual( IPv4Address( "192.168.1.23" )?.description, "192.168.1.23" )
        XCTAssertEqual( IPv4Address( " 10.0.0.1 " )?.description, "10.0.0.1" )
        XCTAssertEqual( IPv4Address( "0.0.0.0" )?.value, 0 )
        XCTAssertEqual( IPv4Address( "255.255.255.255" )?.value, UInt32.max )
    }

    func testParseInvalid() {
        for bad in [ "", "1.2.3", "1.2.3.4.5", "256.1.1.1", "a.b.c.d", "1..2.3", "1.2.3.-4", "1.2.3.1234" ] {
            XCTAssertNil( IPv4Address( bad ), bad )
        }
    }

    func testCIDRNormalisesAndContains() {
        let net = IPv4Network( cidr: "192.168.1.57/24" )!
        XCTAssertEqual( net.base.description, "192.168.1.0" )
        XCTAssertEqual( net.last.description, "192.168.1.255" )
        XCTAssertEqual( net.count, 256 )
        XCTAssertEqual( net.maskString, "255.255.255.0" )
        XCTAssertTrue( net.contains( IPv4Address( "192.168.1.0" )! ) )
        XCTAssertTrue( net.contains( IPv4Address( "192.168.1.255" )! ) )
        XCTAssertFalse( net.contains( IPv4Address( "192.168.2.0" )! ) )
        XCTAssertFalse( net.contains( IPv4Address( "192.168.0.255" )! ) )
    }

    func testPrefixEdges() {
        XCTAssertEqual( IPv4Network( cidr: "0.0.0.0/0" )!.count, 4_294_967_296 )
        XCTAssertTrue( IPv4Network( cidr: "0.0.0.0/0" )!.contains( IPv4Address( "8.8.8.8" )! ) )
        XCTAssertEqual( IPv4Network( cidr: "10.0.0.4/31" )!.count, 2 )
        let host = IPv4Network( cidr: "10.0.0.4/32" )!
        XCTAssertTrue( host.contains( IPv4Address( "10.0.0.4" )! ) )
        XCTAssertFalse( host.contains( IPv4Address( "10.0.0.5" )! ) )
        XCTAssertNil( IPv4Network( cidr: "10.0.0.4/33" ) )
        XCTAssertNil( IPv4Network( cidr: "10.0.0.4" ) )
    }

    func testMask() {
        XCTAssertEqual( IPv4Network.prefix( fromMask: "255.255.255.0" ), 24 )
        XCTAssertEqual( IPv4Network.prefix( fromMask: "255.255.0.0" ), 16 )
        XCTAssertEqual( IPv4Network.prefix( fromMask: "255.255.255.255" ), 32 )
        XCTAssertEqual( IPv4Network.prefix( fromMask: "0.0.0.0" ), 0 )
        XCTAssertNil( IPv4Network.prefix( fromMask: "255.0.255.0" ) )
        XCTAssertNil( IPv4Network.prefix( fromMask: "255.255.255.1" ) )
        XCTAssertNil( IPv4Network.prefix( fromMask: "nope" ) )
    }
}

final class DraftTests: XCTestCase {
    func testPresets() {
        let ip = "192.168.1.23"
        XCTAssertEqual( try NetworkDraft( address: ip, preset: .exactAddress ).resolve().get().prefix, 32 )
        XCTAssertEqual( try NetworkDraft( address: ip, preset: .sameLocalNetwork ).resolve().get().prefix, 24 )
        XCTAssertEqual( try NetworkDraft( address: ip, preset: .largerNetwork ).resolve().get().prefix, 16 )
    }

    func testCustomForms() {
        XCTAssertEqual( try NetworkDraft( address: "10.1.2.3", preset: .custom, custom: "/20" ).resolve().get().prefix, 20 )
        XCTAssertEqual( try NetworkDraft( address: "10.1.2.3", preset: .custom, custom: "20" ).resolve().get().prefix, 20 )
        XCTAssertEqual( try NetworkDraft( address: "10.1.2.3", preset: .custom, custom: "255.255.240.0" ).resolve().get().prefix, 20 )
    }

    func testErrors() {
        XCTAssertThrowsError( try NetworkDraft( address: "bogus" ).resolve().get() )
        XCTAssertThrowsError( try NetworkDraft( address: "10.1.2.3", preset: .custom, custom: "255.0.255.0" ).resolve().get() )
        XCTAssertThrowsError( try NetworkDraft( address: "10.1.2.3", preset: .custom, custom: "40" ).resolve().get() )
    }

    func testSummary() {
        let net = IPv4Network( cidr: "192.168.1.9/24" )
        XCTAssertEqual( RequiredNetwork.summary( for: net ), "192.168.1.0 – 192.168.1.255 (256 addresses)" )
        XCTAssertEqual( RequiredNetwork.summary( for: IPv4Network( cidr: "10.0.0.5/32" ) ), "Only 10.0.0.5 (1 address)" )
    }
}

final class PolicyTests: XCTestCase {
    let required = RequiredNetwork( address: "192.168.1.0", prefix: 24, preset: .sameLocalNetwork )
    func ip( _ s: String ) -> IPv4Address { IPv4Address( s )! }

    func testTruthTable() {
        XCTAssertEqual( Policy.state( addresses: [ ip( "192.168.1.5" ) ], required: nil ), .notConfigured )
        XCTAssertEqual( Policy.state( addresses: [], required: nil ), .notConfigured )
        XCTAssertEqual( Policy.state( addresses: [ ip( "192.168.1.5" ) ], required: required ), .allowed )
        XCTAssertEqual( Policy.state( addresses: [ ip( "10.0.0.5" ) ], required: required ), .blocked )
        XCTAssertEqual( Policy.state( addresses: [], required: required ), .blocked )
        XCTAssertEqual( Policy.state( addresses: [ ip( "10.0.0.5" ), ip( "192.168.1.9" ) ], required: required ), .allowed )
    }
}

final class MockController: ProcessController {
    var running: [RunningTarget] = []
    var log: [String] = []
    func runningTargets( bundleIDs: Set<String> ) -> [RunningTarget] { running.filter { bundleIDs.contains( $0.bundleID ) } }
    func terminate( pid: Int32 ) { log.append( "terminate \( pid )" ) }
    func forceTerminate( pid: Int32 ) { log.append( "force \( pid )" ) }
    func kill( pid: Int32 ) { log.append( "kill \( pid )" ) }
}

final class EngineTests: XCTestCase {
    var store: SettingsStore!
    var mock: MockController!
    var clock = Date( timeIntervalSince1970: 1000 )
    var engine: EnforcementEngine!
    let good = [ IPv4Address( "192.168.1.5" )! ]
    let bad = [ IPv4Address( "10.0.0.5" )! ]

    override func setUp() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent( "aq-\( UUID() ).json" )
        store = SettingsStore( fileURL: url )
        store.update {
            $0.requiredNetwork = RequiredNetwork( address: "192.168.1.0", prefix: 24, preset: .sameLocalNetwork )
            $0.restrictedApps = [ RestrictedApp( bundleID: "com.x.app", name: "X", path: "/Applications/X.app" ) ]
        }
        mock = MockController()
        mock.running = [ RunningTarget( pid: 42, bundleID: "com.x.app", name: "X" ), RunningTarget( pid: 7, bundleID: "com.other", name: "O" ) ]
        engine = EnforcementEngine( store: store, controller: mock, now: { [unowned self] in self.clock } )
    }

    func testAllowedDoesNothing() {
        XCTAssertEqual( engine.evaluate( addresses: good ), .allowed )
        XCTAssertTrue( mock.log.isEmpty )
    }

    func testNotConfiguredDoesNothing() {
        store.update { $0.requiredNetwork = nil }
        XCTAssertEqual( engine.evaluate( addresses: bad ), .notConfigured )
        XCTAssertTrue( mock.log.isEmpty )
    }

    func testEscalationOrderAndUnlistedAppsUntouched() {
        var notified: [Int32] = []
        engine.onQuit = { notified.append( $0.pid ) }
        engine.evaluate( addresses: bad )
        XCTAssertEqual( mock.log, [ "terminate 42" ] )
        clock += 1
        engine.evaluate( addresses: bad )
        XCTAssertEqual( mock.log, [ "terminate 42" ] )
        clock += 1
        engine.evaluate( addresses: bad )
        XCTAssertEqual( mock.log, [ "terminate 42", "force 42" ] )
        clock += 2
        engine.evaluate( addresses: bad )
        XCTAssertEqual( mock.log, [ "terminate 42", "force 42", "kill 42" ] )
        XCTAssertEqual( notified, [ 42 ] )
    }

    func testRelaunchedAppIsQuitAgain() {
        engine.evaluate( addresses: bad )
        mock.running = [ RunningTarget( pid: 99, bundleID: "com.x.app", name: "X" ) ]
        engine.evaluate( addresses: bad )
        XCTAssertEqual( mock.log, [ "terminate 42", "terminate 99" ] )
    }

    func testRegainingNetworkResetsEscalation() {
        engine.evaluate( addresses: bad )
        engine.evaluate( addresses: good )
        clock += 10
        engine.evaluate( addresses: bad )
        XCTAssertEqual( mock.log, [ "terminate 42", "terminate 42" ] )
    }

    func testNoInterfacesFailsClosed() {
        XCTAssertEqual( engine.evaluate( addresses: [] ), .blocked )
        XCTAssertEqual( mock.log, [ "terminate 42" ] )
    }
}

final class SettingsTests: XCTestCase {
    func testRoundTrip() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent( "aq-\( UUID() )/settings.json" )
        let a = SettingsStore( fileURL: url )
        a.update {
            $0.requiredNetwork = RequiredNetwork( address: "10.0.0.0", prefix: 8, preset: .custom )
            $0.restrictedApps = [ RestrictedApp( bundleID: "com.y", name: "Y", path: "/Applications/Y.app" ) ]
        }
        let b = SettingsStore( fileURL: url )
        XCTAssertEqual( a.settings, b.settings )
        XCTAssertEqual( b.settings.restrictedApps.count, 1 )
    }
}
