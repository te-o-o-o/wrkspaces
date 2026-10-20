// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "wrkspaces",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure workspace state, no AppKit: testable without a screen or permissions.
        .target(name: "WrkspacesCore"),
        .testTarget(name: "WrkspacesCoreTests", dependencies: ["WrkspacesCore"]),
    ],
    // Swift 5 mode: the AX and Carbon C callbacks fight Swift 6 strict concurrency for no real gain here.
    swiftLanguageModes: [.v5]
)
