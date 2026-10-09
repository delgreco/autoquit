// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AutoQuit",
    platforms: [ .macOS( .v13 ) ],
    targets: [
        .target( name: "AutoQuitCore" ),
        .executableTarget( name: "AutoQuit", dependencies: [ "AutoQuitCore" ] ),
        .testTarget( name: "AutoQuitTests", dependencies: [ "AutoQuitCore" ] ),
    ]
)
