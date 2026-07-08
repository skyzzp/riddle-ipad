// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RiddleKit",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "RiddleKit", targets: ["RiddleKit"]),
    ],
    targets: [
        .target(name: "RiddleKit", resources: [.copy("Resources/AquilineTwo.ttf")]),
        .testTarget(name: "RiddleKitTests", dependencies: ["RiddleKit"]),
    ]
)
