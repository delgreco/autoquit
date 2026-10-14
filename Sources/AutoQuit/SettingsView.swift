import SwiftUI
import AppKit
import AutoQuitCore

/// The settings window content: Required Network editor, restricted app list, live status.
struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var monitor: NetworkMonitor

    @State private var draft: NetworkDraft
    @State private var selection = Set<String>()
    @State private var justSaved = false
    @State private var launchAtStartup = LoginItem.isInstalled
    private let wasUnconfigured: Bool
    private let detectedIP: String?

    init( store: SettingsStore, monitor: NetworkMonitor ) {
        self.store = store
        self.monitor = monitor
        let detected = InterfaceReader().currentPrimaryIP()?.description
        detectedIP = detected
        if let saved = store.settings.requiredNetwork {
            wasUnconfigured = false
            _draft = State( initialValue: NetworkDraft( network: saved ) )
        }
        else {
            // Pre-populate with the current IP so setup is one click.
            wasUnconfigured = true
            _draft = State( initialValue: NetworkDraft( detectedIP: detected ?? "" ) )
        }
    }

    var body: some View {
        VStack( alignment: .leading, spacing: 16 ) {
            networkSection
            Divider()
            appsSection
            Divider()
            startupSection
            Divider()
            statusFooter
        }
        .padding( 20 )
        .frame( minWidth: 580, idealWidth: 620, minHeight: 740, idealHeight: 760 )
    }

    // MARK: Required Network

    private var resolved: Result<IPv4Network, DraftError> { draft.resolve() }

    private var isSaved: Bool {
        guard let saved = store.settings.requiredNetwork, case .success( let net ) = resolved else { return false }
        return saved.address == net.base.description && saved.prefix == net.prefix && saved.notation == draft.notation
    }

    private func useCurrentIP() {
        guard let ip = detectedIP else { return }
        if let addr = IPv4Address( ip ), let net = IPv4Network( address: addr, prefix: 24 ) {
            draft.cidrText = "\( ip )/24"
            draft.wildcardText = NetworkDraft.toWildcard( network: net ) ?? "\( ip )"
        }
        else {
            draft.cidrText = "\( ip )/24"
            draft.wildcardText = ip
        }
    }

    private var networkSection: some View {
        VStack( alignment: .leading, spacing: 10 ) {
            Text( "Required Network" ).font( .headline )
            Text( "Restricted apps may only run while this Mac has an IP address inside this network." )
                .font( .callout ).foregroundStyle( .secondary )

            if let detectedIP = detectedIP {
                HStack {
                    Text( wasUnconfigured && store.settings.requiredNetwork == nil ? "You're currently on \( detectedIP )." : "This Mac's current IP: \( detectedIP )" )
                        .font( .callout )
                    Spacer()
                    Button( "Use my current IP" ) { useCurrentIP() }
                }
            }

            Picker( "Notation", selection: Binding(
                get: { draft.notation },
                set: { newNotation in
                    if newNotation != draft.notation {
                        if case .success( let net ) = draft.resolve() {
                            if newNotation == .wildcard, let wc = NetworkDraft.toWildcard( network: net ) {
                                draft.wildcardText = wc
                            }
                            else if newNotation == .cidr {
                                draft.cidrText = NetworkDraft.toCIDR( network: net )
                            }
                        }
                        draft.notation = newNotation
                    }
                }
            ) ) {
                ForEach( NetworkNotation.allCases, id: \.self ) { notation in
                    Text( notation.title ).tag( notation )
                }
            }
            .pickerStyle( .radioGroup )

            if draft.notation == .cidr {
                HStack {
                    TextField( "CIDR notation", text: $draft.cidrText, prompt: Text( "192.168.1.0/24" ) )
                        .textFieldStyle( .roundedBorder )
                    Text( "Example: 192.168.1.0/24 or 10.0.0.0/8" )
                        .font( .caption ).foregroundStyle( .secondary )
                }
            }
            else {
                HStack {
                    TextField( "Wildcard notation", text: $draft.wildcardText, prompt: Text( "192.168.1.*" ) )
                        .textFieldStyle( .roundedBorder )
                    Text( "Example: 192.168.1.*, 192.168.*.*, or 10.*.*.*" )
                        .font( .caption ).foregroundStyle( .secondary )
                }
            }

            switch resolved {
                case .success( let net ):
                    Label( RequiredNetwork.summary( for: net ), systemImage: "checkmark.circle.fill" )
                        .foregroundStyle( .green )
                case .failure( let error ):
                    Label( error.message, systemImage: "exclamationmark.triangle.fill" )
                        .foregroundStyle( .red )
            }

            HStack {
                Button( "Save Network" ) { saveNetwork() }
                    .keyboardShortcut( .defaultAction )
                    .disabled( isSaved || { if case .failure = resolved { return true } else { return false } }() )
                if store.settings.requiredNetwork != nil {
                    Button( "Turn Off Enforcement" ) { store.update { $0.requiredNetwork = nil } }
                }
                if justSaved || isSaved { Text( "Saved" ).foregroundStyle( .secondary ) }
            }
        }
    }

    private func saveNetwork() {
        guard case .success( let net ) = resolved else { return }
        store.update { $0.requiredNetwork = RequiredNetwork( address: net.base.description, prefix: net.prefix, notation: draft.notation ) }
        justSaved = true
    }

    // MARK: Restricted apps

    private var appsSection: some View {
        VStack( alignment: .leading, spacing: 8 ) {
            Text( "Restricted Apps" ).font( .headline )
            Text( "These apps are quit immediately (and force-quit if needed) whenever you're off the Required Network. Drag apps here or use +." )
                .font( .callout ).foregroundStyle( .secondary )

            List( selection: $selection ) {
                ForEach( store.settings.restrictedApps ) { app in
                    HStack {
                        Image( nsImage: NSWorkspace.shared.icon( forFile: app.path ) )
                            .resizable().frame( width: 24, height: 24 )
                        Text( app.name )
                        Spacer()
                        Text( app.bundleID ).font( .caption ).foregroundStyle( .secondary )
                    }
                    .tag( app.id )
                }
            }
            .frame( minHeight: 160 )
            .onDrop( of: [ .fileURL ], isTargeted: nil ) { providers in
                for provider in providers {
                    _ = provider.loadObject( ofClass: URL.self ) { url, _ in
                        if let url = url { DispatchQueue.main.async { addApps( [ url ] ) } }
                    }
                }
                return true
            }

            HStack {
                Button( action: chooseApps ) { Image( systemName: "plus" ) }.help( "Add apps" )
                Button( action: removeSelected ) { Image( systemName: "minus" ) }
                    .help( "Remove selected apps" )
                    .disabled( selection.isEmpty )
                Spacer()
            }
        }
    }

    private func chooseApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [ .applicationBundle ]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL( fileURLWithPath: "/Applications" )
        panel.prompt = "Add"
        if panel.runModal() == .OK { addApps( panel.urls ) }
    }

    private func addApps( _ urls: [URL] ) {
        let apps = urls.filter { $0.pathExtension == "app" }.compactMap { RestrictedApp( url: $0 ) }
        store.update { settings in
            for app in apps where !settings.restrictedApps.contains( where: { $0.bundleID == app.bundleID } ) {
                settings.restrictedApps.append( app )
            }
        }
    }

    private func removeSelected() {
        store.update { $0.restrictedApps.removeAll( where: { selection.contains( $0.id ) } ) }
        selection.removeAll()
    }

    // MARK: Startup & Quit

    private var startupSection: some View {
        HStack {
            Toggle( "Launch at Login", isOn: Binding(
                get: { launchAtStartup },
                set: { newValue in
                    launchAtStartup = newValue
                    if newValue {
                        LoginItem.writePlist()
                    }
                    else {
                        LoginItem.uninstall()
                    }
                }
            ) )
            Spacer()
            Button( "Quit AutoQuit" ) {
                NSApp.terminate( nil )
            }
            .keyboardShortcut( "q", modifiers: .command )
        }
    }

    // MARK: Status

    private var statusFooter: some View {
        let state = Policy.state( addresses: monitor.addresses, required: store.settings.requiredNetwork )
        let ips = monitor.addresses.isEmpty ? "no network" : monitor.addresses.map { $0.description }.joined( separator: ", " )
        return HStack {
            switch state {
                case .notConfigured: Label( "Not enforcing – no Required Network saved", systemImage: "pause.circle" )
                case .allowed: Label( "On required network", systemImage: "checkmark.shield.fill" ).foregroundStyle( .green )
                case .blocked: Label( "Off network – restricted apps are blocked", systemImage: "xmark.shield.fill" ).foregroundStyle( .red )
            }
            Spacer()
            Text( "Current IP: \( ips )" ).font( .caption ).foregroundStyle( .secondary )
        }
    }
}
