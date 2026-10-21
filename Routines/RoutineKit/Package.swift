// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RoutineKit",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0")
    ],
    products: [
        .library(name: "RoutineKit", targets: ["RoutineKit"])
    ],
    targets: [
        .target(name: "RoutineKit"),
        .testTarget(name: "RoutineKitTests", dependencies: ["RoutineKit"])
    ]
)
