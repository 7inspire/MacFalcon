// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacMonitor",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "MacMonitor", targets: ["MacMonitor"])],
    targets: [
        .target(name: "MonitorCore", publicHeadersPath: "include"),
        .systemLibrary(name: "CSQLite"),
        .executableTarget(name: "MacMonitor", dependencies: ["MonitorCore", "CSQLite"], linkerSettings: [.linkedFramework("IOKit")]),
        .testTarget(name: "MonitorCoreTests", dependencies: ["MonitorCore", "MacMonitor"])
    ]
)
