// swift-tools-version: 6.0
// Lets `swift test` check the app's pure logic (FindersKeepers/Core) without a phone or simulator.
import PackageDescription

let package = Package(
    name: "FKCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    targets: [
        .target(name: "FKCore", path: "FindersKeepers/Core"),
        .testTarget(name: "FKCoreTests", dependencies: ["FKCore"], path: "Tests/FKCoreTests"),
    ]
)
