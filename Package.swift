// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "FMMini",
    platforms: [.macOS(.v27)],
    products: [.executable(name: "FMMini", targets: ["FMMini"])],
    targets: [.executableTarget(name: "FMMini")]
)
